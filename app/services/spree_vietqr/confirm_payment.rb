# frozen_string_literal: true

module SpreeVietqr
  class ConfirmPayment
    def initialize(payment_method:)
      @payment_method = payment_method
    end

    def call(allocation:, webhook_event: nil)
      delivery_order = nil

      ActiveRecord::Base.transaction do
        allocation.lock!
        order = allocation.order
        payment = allocation.payment

        order.lock!
        order.reload

        payment.lock!
        payment.reload

        if allocation.confirmed? || order.payment_state == 'paid' || payment.state == 'completed'
          mark_duplicate!(allocation: allocation, payment: payment, webhook_event: webhook_event)
          return false
        end

        unless payment.state.in?(%w[checkout pending processing])
          webhook_event&.mark_status!('unmatched')
          return false
        end

        actual_amount = received_amount(webhook_event: webhook_event, allocation: allocation)
        expected_amount = allocation.expected_amount.to_i

        if actual_amount != expected_amount && order.user.blank?
          webhook_event&.mark_status!('unmatched', error: 'Amount mismatch cannot be converted to wallet credit because the order has no logged-in user')
          return false
        end

        if actual_amount < expected_amount
          store_credit = credit_wallet!(
            order: order,
            allocation: allocation,
            webhook_event: webhook_event,
            amount: actual_amount,
            kind: 'underpayment'
          )
          increment_account_confirmed_amount!(allocation.receiving_account, actual_amount)
          mark_underpaid_as_credited!(allocation: allocation, payment: payment, webhook_event: webhook_event, store_credit: store_credit, actual_amount: actual_amount)
          return true
        end

        payment.complete!
        confirm_allocation!(allocation, webhook_event: webhook_event, confirmed_amount: actual_amount)
        delivery_order = order

        overpaid_credit = nil
        if actual_amount > expected_amount
          overpaid_credit = credit_wallet!(
            order: order,
            allocation: allocation,
            webhook_event: webhook_event,
            amount: actual_amount - expected_amount,
            kind: 'overpayment'
          )
        end

        webhook_event&.update!(
          status: 'confirmed',
          matched_order_number: order.number,
          payment: payment,
          payment_allocation: allocation,
          receiving_account: allocation.receiving_account,
          error_message: overpaid_credit ? "Overpayment credited to wallet: #{overpaid_credit.amount.to_i} VND" : nil,
          processed_at: Time.current
        )
      end

      enqueue_delivery_if_needed(delivery_order)
      true
    rescue StandardError => e
      webhook_event&.mark_status!('error', error: e.message)
      false
    end

    private

    def received_amount(webhook_event:, allocation:)
      amount = webhook_event&.amount_cents.to_i
      amount.positive? ? amount : allocation.expected_amount.to_i
    end

    def confirm_allocation!(allocation, webhook_event: nil, confirmed_amount: allocation.expected_amount.to_i)
      increment_account_confirmed_amount!(allocation.receiving_account, confirmed_amount)

      allocation.update!(
        status: 'confirmed',
        confirmed_at: Time.current,
        webhook_event: webhook_event || allocation.webhook_event
      )
    end

    def increment_account_confirmed_amount!(account, amount)
      return unless account

      account.reset_period_if_needed!
      account.with_lock do
        account.update!(period_confirmed_amount: account.period_confirmed_amount.to_i + amount.to_i)
      end
    end

    def credit_wallet!(order:, allocation:, webhook_event:, amount:, kind:)
      category = Spree::StoreCreditCategory.find_or_create_by!(name: 'Topup VietQR')
      credit_type = Spree::StoreCreditType.find_or_create_by!(name: 'Non-expiring') do |type|
        type.priority = 1
      end

      store_credit = Spree::StoreCredit.create!(
        user: order.user,
        category: category,
        type_id: credit_type.id,
        amount: amount,
        currency: order.currency.presence || 'VND',
        memo: wallet_credit_memo(kind: kind, order: order, allocation: allocation, webhook_event: webhook_event, amount: amount),
        store: order.respond_to?(:store) ? order.store : Spree::Store.default,
        originator: webhook_event,
        private_metadata: wallet_credit_metadata(kind: kind, order: order, allocation: allocation, webhook_event: webhook_event, amount: amount)
      )

      audit_wallet_credit!(kind: kind, order: order, allocation: allocation, webhook_event: webhook_event, store_credit: store_credit, amount: amount)
      store_credit
    end

    def wallet_credit_memo(kind:, order:, allocation:, webhook_event:, amount:)
      reason = kind == 'underpayment' ? 'Chuyển thiếu đơn hàng' : 'Chuyển thừa đơn hàng'
      reference = bank_reference(webhook_event).presence || webhook_event&.provider_transaction_id.presence || webhook_event&.id
      "#{reason} #{order.number}: #{amount.to_i} VND - #{allocation.transfer_content} - webhook #{reference}"
    end

    def wallet_credit_metadata(kind:, order:, allocation:, webhook_event:, amount:)
      {
        source: 'vietqr_order_payment',
        kind: kind,
        amount: amount.to_i,
        order_number: order.number,
        expected_amount: allocation.expected_amount.to_i,
        received_amount: webhook_event&.amount_cents.to_i,
        transfer_content: allocation.transfer_content,
        payment_id: allocation.payment_id,
        payment_allocation_id: allocation.id,
        webhook_event_id: webhook_event&.id,
        provider: webhook_event&.provider,
        provider_transaction_id: webhook_event&.provider_transaction_id,
        bank_reference: bank_reference(webhook_event),
        receiving_account_id: allocation.receiving_account_id
      }
    end

    def bank_reference(webhook_event)
      webhook_event&.raw_payload.to_h['referenceCode'].presence || webhook_event&.raw_payload.to_h['reference'].presence
    end

    def audit_wallet_credit!(kind:, order:, allocation:, webhook_event:, store_credit:, amount:)
      return unless defined?(Mmo::AuditLog)

      Mmo::AuditLog.create!(
        user: order.user,
        action: kind == 'underpayment' ? 'vietqr_underpayment_credited' : 'vietqr_overpayment_credited',
        metadata: wallet_credit_metadata(kind: kind, order: order, allocation: allocation, webhook_event: webhook_event, amount: amount).merge(
          store_credit_id: store_credit.id,
          new_balance: order.user.total_available_store_credit.to_i
        )
      )
    end

    def mark_underpaid_as_credited!(allocation:, payment:, webhook_event:, store_credit:, actual_amount:)
      webhook_event&.update!(
        status: 'confirmed',
        matched_order_number: allocation.order_number,
        payment: payment,
        payment_allocation: allocation,
        receiving_account: allocation.receiving_account,
        error_message: "Underpayment credited to wallet: #{actual_amount.to_i} VND (store credit ##{store_credit.id}); order remains unpaid",
        processed_at: Time.current
      )
    end

    def mark_duplicate!(allocation:, payment:, webhook_event:)
      webhook_event&.update!(
        status: 'duplicate',
        matched_order_number: allocation.order_number,
        payment: payment,
        payment_allocation: allocation,
        receiving_account: allocation.receiving_account,
        processed_at: Time.current
      )
    end

    def enqueue_delivery_if_needed(order)
      return unless order && defined?(Mmo::DeliverOrderJob)

      order.reload
      return unless order.respond_to?(:mmo_order?) && order.mmo_order?
      return unless order.payment_state == 'paid'
      return if defined?(Mmo::Delivery) && Mmo::Delivery.for_order(order).active.exists?

      Mmo::DeliverOrderJob.perform_later(order.id)
    end
  end
end
