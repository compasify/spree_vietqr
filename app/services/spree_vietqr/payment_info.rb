# frozen_string_literal: true

module SpreeVietqr
  class PaymentInfo
    PAYABLE_PAYMENT_STATES = %w[checkout pending processing].freeze

    attr_reader :qr_url, :bank_name, :account_number, :account_name,
                :amount, :transfer_content, :order_number, :checkout_url, :payment_link_id

    BANK_NAMES = {
      "970422" => "MB Bank",
      "970415" => "VietinBank",
      "970436" => "Vietcombank",
      "970418" => "BIDV",
      "970407" => "Techcombank",
      "970416" => "ACB",
      "970432" => "VPBank",
      "970423" => "TPBank",
      "970448" => "OCB",
      "970437" => "HDBank",
      "970403" => "Sacombank",
      "970405" => "Agribank",
      "970441" => "VIB",
      "970443" => "SHB",
      "970454" => "VietCapital Bank",
      "970449" => "LPBank",
      "970431" => "Eximbank",
      "970426" => "MSB",
      "970414" => "OceanBank",
      "970429" => "SCB"
    }.freeze

    # @param payment_method [Spree::PaymentMethod::Vietqr]
    # @param order [Spree::Order]
    def initialize(payment_method:, order:, request_base_url: nil)
      payment = self.class.find_payable_payment!(payment_method: payment_method, order: order)
      allocation = AllocatePaymentAccount.new(
        payment_method: payment_method,
        order: order,
        payment: payment,
        request_base_url: request_base_url
      ).call

      @qr_url = GenerateQr.new.call(payment_method: payment_method, order: order, allocation: allocation)
      @bank_name = resolve_bank_name(allocation.bank_bin)
      @account_number = allocation.account_number
      @account_name = allocation.account_name
      @amount = allocation.expected_amount.to_i
      @transfer_content = allocation.transfer_content
      @order_number = allocation.order_number
      @checkout_url = allocation.provider_checkout_url
      @payment_link_id = allocation.payment_link_id
    end

    def to_h
      {
        qr_url: qr_url,
        bank_name: bank_name,
        account_number: account_number,
        account_name: account_name,
        amount: amount,
        currency: "VND",
        transfer_content: transfer_content,
        order_number: order_number,
        checkout_url: checkout_url,
        payment_link_id: payment_link_id
      }.compact
    end

    def self.find_payable_payment(payment_method:, order:)
      payment_from_active_allocation(payment_method: payment_method, order: order) ||
        order.payments
             .where(payment_method: payment_method, state: PAYABLE_PAYMENT_STATES)
             .order(:id)
             .last
    end

    def self.find_payable_payment!(payment_method:, order:)
      payment = find_payable_payment(payment_method: payment_method, order: order)
      return payment if payment

      raise ActiveRecord::RecordNotFound, 'No pending VietQR payment found for this order'
    end

    private

    def resolve_bank_name(bin)
      BANK_NAMES[bin] || "Bank #{bin}"
    end

    def self.payment_from_active_allocation(payment_method:, order:)
      return unless defined?(PaymentAllocation)

      allocation = PaymentAllocation.active
                                   .where(order: order, payment_method: payment_method)
                                   .ordered_recently
                                   .includes(:payment)
                                   .detect { |record| record.payment&.state.in?(PAYABLE_PAYMENT_STATES) }

      allocation&.payment
    end
  end
end
