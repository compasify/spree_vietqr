# frozen_string_literal: true

require 'uri'

module SpreeVietqr
  class GenerateQr
    VIETQR_BASE_URL = "https://img.vietqr.io/image"
    DEFAULT_TEMPLATE = "compact2"

    # @param payment_method [Spree::PaymentMethod::Vietqr]
    # @param order [Spree::Order]
    # @return [String] VietQR image URL
    def call(payment_method:, order:)
      bank_bin = payment_method.preferred_bank_bin
      account_number = payment_method.preferred_account_number
      account_name = payment_method.preferred_account_name
      amount = order.total.to_i
      transfer_content = format_transfer_content(order)

      build_url(
        bank_bin: bank_bin,
        account_number: account_number,
        account_name: account_name,
        amount: amount,
        transfer_content: transfer_content
      )
    end

    # Generate QR URL for a topup request (no order needed)
    # @param payment_method [Spree::PaymentMethod::Vietqr]
    # @param amount [Integer]
    # @param transfer_content [String]
    # @return [String] VietQR image URL
    def call_for_topup(payment_method:, amount:, transfer_content:)
      build_url(
        bank_bin: payment_method.preferred_bank_bin,
        account_number: payment_method.preferred_account_number,
        account_name: payment_method.preferred_account_name,
        amount: amount,
        transfer_content: transfer_content
      )
    end

    private

    def format_transfer_content(order)
      "MMO#{order.number}"
    end

    def build_url(bank_bin:, account_number:, account_name:, amount:, transfer_content:)
      base = "#{VIETQR_BASE_URL}/#{bank_bin}-#{account_number}-#{DEFAULT_TEMPLATE}.png"
      params = URI.encode_www_form(
        amount: amount,
        addInfo: transfer_content,
        accountName: account_name
      )
      "#{base}?#{params}"
    end
  end
end
