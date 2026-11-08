# frozen_string_literal: true

module SpreeVietqr
  # What a checkout screen (storefront or POS) shows for an order paid by
  # VietQR: the QR and bank details while a transfer is awaited, or the
  # confirmed state once the money has been matched.
  #
  # Showing the QR reserves a receiving account for the payment, so this is
  # only called for an order the caller is allowed to pay.
  class OrderPaymentSummary
    def self.call(order:, payment_method: nil, payment: nil, request_base_url: nil)
      new(order: order, payment_method: payment_method, payment: payment, request_base_url: request_base_url).call
    end

    def initialize(order:, payment_method:, payment:, request_base_url:)
      @order = order
      @payment = payment
      @payment_method = payment_method || payment&.payment_method || vietqr_method
      @request_base_url = request_base_url
    end

    # @return [Hash, nil] nil when the order has no VietQR payment
    def call
      return nil unless @payment_method.is_a?(Spree::PaymentMethod::Vietqr)

      confirmed = confirmed_allocation
      return confirmed_summary(confirmed) if confirmed

      payment = @payment || PaymentInfo.find_payable_payment(payment_method: @payment_method, order: @order)
      return nil unless payment&.status.in?(Spree::PaymentMethod::Vietqr::PAYABLE_PAYMENT_STATUSES)

      info = PaymentInfo.new(payment_method: @payment_method, order: @order, request_base_url: @request_base_url)
      info.to_h.merge(order_payment_status: @order.payment_status)
    end

    private

    def vietqr_method
      @order.payments.joins(:payment_method)
            .where(spree_payment_methods: { type: Spree::PaymentMethod::Vietqr.name })
            .reorder(created_at: :desc).first&.payment_method
    end

    def confirmed_allocation
      scope = PaymentAllocation.where(order: @order, payment_method: @payment_method, status: 'confirmed')
      scope = scope.where(payment: @payment) if @payment
      scope.ordered_recently.first
    end

    def confirmed_summary(allocation)
      {
        status: 'confirmed',
        amount: allocation.expected_amount.to_i,
        currency: @order.currency,
        transfer_content: allocation.transfer_content,
        order_number: allocation.order_number,
        confirmed_at: allocation.confirmed_at&.iso8601,
        payment_id: allocation.payment.prefixed_id,
        order_payment_status: @order.payment_status
      }
    end
  end
end
