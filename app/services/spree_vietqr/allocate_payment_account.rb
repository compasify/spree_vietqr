# frozen_string_literal: true

module SpreeVietqr
  class AllocatePaymentAccount
    DEFAULT_PAYMENT_TIMEOUT_MINUTES = 10

    def initialize(payment_method:, order:, payment:, request_base_url: nil)
      @payment_method = payment_method
      @order = order
      @payment = payment
      @request_base_url = request_base_url
    end

    def call
      validate_payment_binding!

      @payment.with_lock do
        existing = PaymentAllocation.active.find_by(payment: @payment)
        return refresh_existing_allocation!(existing) if existing

        release_replaced_allocations!

        allocation = build_allocation!
        reserve_account_quota!(allocation)
        allocation
      end
    end

    private

    def validate_payment_binding!
      raise ArgumentError, 'Payment must belong to the order' unless @payment.order_id == @order.id
      raise ArgumentError, 'Payment must use the provided VietQR payment method' unless @payment.payment_method_id == @payment_method.id
      raise ArgumentError, 'Payment is not payable' unless @payment.state.in?(%w[checkout pending processing])
    end

    def build_allocation!
      account = select_receiving_account!

      if account.provider == 'payos'
        build_payos_allocation!(account)
      else
        build_standard_allocation!(account)
      end
    end

    def build_standard_allocation!(account)
      PaymentAllocation.create!(
        payment: @payment,
        order: @order,
        payment_method: @payment_method,
        receiving_account: account,
        provider: account.provider,
        bank_bin: account.bank_bin,
        account_number: account.account_number,
        account_name: account.account_name,
        sub_account: account.sub_account,
        virtual_account_number: account.virtual_account_number,
        expected_amount: @payment.amount.to_i,
        transfer_content: transfer_content(account),
        order_number: @order.number,
        expires_at: expires_at
      )
    end

    def build_payos_allocation!(account)
      payos_link = PayosClient.new(payment_method: @payment_method, receiving_account: account).create_payment_link(
        order: @order,
        amount: @payment.amount.to_i,
        return_url: default_return_url,
        cancel_url: default_cancel_url,
        description: transfer_content(account)
      )

      PaymentAllocation.create!(
        payment: @payment,
        order: @order,
        payment_method: @payment_method,
        receiving_account: account,
        provider: account.provider,
        bank_bin: payos_link[:bank_bin].presence || account.bank_bin,
        account_number: payos_link[:account_number].presence || account.account_number,
        account_name: payos_link[:account_name].presence || account.account_name,
        expected_amount: @payment.amount.to_i,
        transfer_content: transfer_content(account),
        order_number: @order.number,
        provider_order_code: payos_link[:provider_order_code],
        payment_link_id: payos_link[:payment_link_id],
        provider_checkout_url: payos_link[:checkout_url],
        provider_qr_code: payos_link[:qr_code],
        expires_at: payos_link[:expires_at].presence || expires_at
      )
    end

    def reserve_account_quota!(allocation)
      account = allocation.receiving_account
      return unless account

      account.reset_period_if_needed!
      account.with_lock do
        account.update!(
          period_allocated_amount: account.period_allocated_amount.to_i + allocation.expected_amount.to_i,
          last_allocated_at: Time.current
        )
      end
    end

    def select_receiving_account!
      accounts = @payment_method.active_receiving_accounts.lock
      account = ReceivingAccountSelector.new(
        payment_method: @payment_method,
        amount: @payment.amount.to_i,
        accounts: accounts
      ).call

      return account if account

      raise ActiveRecord::RecordNotFound, 'No eligible VietQR receiving account is available'
    end

    def release_replaced_allocations!
      PaymentAllocation.active.where(order: @order, payment_method: @payment_method).where.not(payment: @payment).find_each do |allocation|
        ReleasePaymentAllocation.new.call(allocation: allocation, reason: 'payment_replaced')
      end
    end

    def refresh_existing_allocation!(allocation)
      expected_transfer_content = transfer_content(allocation.receiving_account)
      return allocation if allocation.transfer_content == expected_transfer_content

      allocation.update!(transfer_content: expected_transfer_content)
      allocation
    end

    def transfer_content(account)
      prefix = account&.keyword_init.to_s.strip.presence || 'MMO'
      "#{prefix}#{@order.number}"
    end

    def expires_at
      @order.created_at + DEFAULT_PAYMENT_TIMEOUT_MINUTES.minutes
    end

    def default_return_url
      "#{base_url}/"
    end

    def default_cancel_url
      "#{base_url}/"
    end

    def base_url
      raw = @request_base_url.presence || Spree::Store.default&.url.presence || 'http://localhost:3000'
      raw.start_with?('http://', 'https://') ? raw : "https://#{raw}"
    end
  end
end
