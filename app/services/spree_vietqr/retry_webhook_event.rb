# frozen_string_literal: true

module SpreeVietqr
  # Parses and matches a stored webhook event again, for events that arrived
  # before their order's QR was shown or failed while being processed.
  class RetryWebhookEvent
    def initialize(event:, payment_method:)
      @event = event
      @payment_method = payment_method
    end

    # @return [Boolean] whether a payment was confirmed
    def call
      provider = Providers::Registry.resolve(@event.provider).new(payment_method: @payment_method, receiving_account: @event.receiving_account)
      transaction = provider.parse_transaction(@event.raw_payload.with_indifferent_access)
      allocation = MatchTransaction.new(payment_method: @payment_method, receiving_account: @event.receiving_account).call(transaction)

      if allocation
        @event.update!(matched_order_number: allocation.order_number, payment_allocation: allocation, receiving_account: allocation.receiving_account)
        return ConfirmPayment.new(payment_method: @payment_method).call(allocation: allocation, webhook_event: @event)
      end

      @event.mark_status!('unmatched')
      false
    rescue StandardError => e
      @event.mark_status!('error', error: e.message)
      false
    end
  end
end
