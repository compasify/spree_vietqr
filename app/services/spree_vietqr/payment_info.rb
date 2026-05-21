# frozen_string_literal: true

module SpreeVietqr
  class PaymentInfo
    attr_reader :qr_url, :bank_name, :account_number, :account_name,
                :amount, :transfer_content, :order_number

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
    def initialize(payment_method:, order:)
      @qr_url = GenerateQr.new.call(payment_method: payment_method, order: order)
      @bank_name = resolve_bank_name(payment_method.preferred_bank_bin)
      @account_number = payment_method.preferred_account_number
      @account_name = payment_method.preferred_account_name
      @amount = order.total.to_i
      @transfer_content = "MMO#{order.number}"
      @order_number = order.number
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
        order_number: order_number
      }
    end

    private

    def resolve_bank_name(bin)
      BANK_NAMES[bin] || "Bank #{bin}"
    end
  end
end
