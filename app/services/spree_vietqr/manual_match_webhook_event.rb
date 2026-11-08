# frozen_string_literal: true

module SpreeVietqr
  # Staff matches a stored webhook event to an order by hand. The amount and
  # the receiving account of the order's allocation are still checked before
  # the payment is confirmed.
  class ManualMatchWebhookEvent
    Result = Struct.new(:success, :error, keyword_init: true) do
      def success?
        success
      end
    end

    def initialize(event:, payment_method:)
      @event = event
      @payment_method = payment_method
    end

    def call(order:)
      return failure('Order not found') unless order
      return failure('Webhook event has no amount') if @event.amount_cents.blank?

      allocation = matching_allocation(order)
      return failure('No pending VietQR allocation matches this webhook amount and receiving account') unless allocation

      confirmed = ConfirmPayment.new(payment_method: @payment_method).call(allocation: allocation, webhook_event: @event)
      confirmed ? Result.new(success: true) : failure(@event.reload.error_message.presence || 'Failed to confirm payment')
    end

    private

    def failure(message)
      Result.new(success: false, error: message)
    end

    def matching_allocation(order)
      PaymentAllocation.active
                       .where(order: order, payment_method: @payment_method, status: 'allocated')
                       .where(expected_amount: @event.amount_cents.to_i)
                       .find { |allocation| account_matches?(allocation) }
    end

    def account_matches?(allocation)
      return false if @event.account_number.blank? && @event.virtual_account_number.blank? && @event.payment_link_id.blank?
      return true if @event.payment_link_id.present? && allocation.payment_link_id == @event.payment_link_id
      return true if @event.receiving_account_id.present? && allocation.receiving_account_id == @event.receiving_account_id

      account = @event.account_number.present? && AccountIdentifier.account_number_matches?(allocation.account_number, @event.account_number)
      event_bin = AccountIdentifier.normalize_number(@event.bank_bin)
      bank = event_bin.blank? || AccountIdentifier.normalize_number(allocation.bank_bin) == event_bin
      sub_account = allocation.sub_account.blank? ||
                    (@event.sub_account.present? && allocation.sub_account == AccountIdentifier.normalize_text(@event.sub_account))
      virtual_account = allocation.virtual_account_number.blank? ||
                        (@event.virtual_account_number.present? &&
                          AccountIdentifier.normalize_number(allocation.virtual_account_number) == AccountIdentifier.normalize_number(@event.virtual_account_number))

      account && bank && sub_account && virtual_account
    end
  end
end
