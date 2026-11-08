# frozen_string_literal: true

module SpreeVietqr
  # The VietQR payment method a stored webhook event belongs to, for events
  # that were rejected or unmatched before one was recorded on them.
  module ResolveEventPaymentMethod
    module_function

    def call(event, scope: Spree::PaymentMethod::Vietqr.all)
      event.payment_allocation&.payment_method ||
        event.payment_method ||
        event.receiving_account&.payment_method ||
        scope.active.detect { |method| method.receiving_accounts.active.for_provider(event.provider).exists? } ||
        scope.active.first
    end
  end
end
