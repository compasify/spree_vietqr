# frozen_string_literal: true

require 'uri'

module SpreeVietqr
  class GenerateQr
    VIETQR_BASE_URL = "https://img.vietqr.io/image"
    DEFAULT_TEMPLATE = "compact2"

    # @param payment_method [Spree::PaymentMethod::Vietqr]
    # @param order [Spree::Order]
    # @return [String] VietQR image URL
    def call(payment_method:, order:, allocation: nil)
      if allocation&.provider_qr_code.to_s.start_with?('http://', 'https://')
        return allocation.provider_qr_code
      end

      account = allocation || default_receiving_account(payment_method)
      bank_bin = account&.bank_bin
      account_number = account&.account_number
      account_name = account&.account_name
      amount = allocation&.expected_amount.to_i.nonzero? || order.total.to_i
      transfer_content = allocation&.transfer_content.presence || format_transfer_content(order)

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
    def call_for_topup(payment_method:, amount:, transfer_content:, receiving_account: nil)
      account = receiving_account || default_receiving_account(payment_method)

      build_url(
        bank_bin: account&.bank_bin,
        account_number: account&.account_number,
        account_name: account&.account_name,
        amount: amount,
        transfer_content: transfer_content
      )
    end

    private

    def format_transfer_content(order)
      "MMO#{order.number}"
    end

    def build_url(bank_bin:, account_number:, account_name:, amount:, transfer_content:)
      raise ArgumentError, 'VietQR receiving account is required' if bank_bin.blank? || account_number.blank? || account_name.blank?

      base = "#{VIETQR_BASE_URL}/#{bank_bin}-#{account_number}-#{DEFAULT_TEMPLATE}.png"
      params = URI.encode_www_form(
        amount: amount,
        addInfo: transfer_content,
        accountName: account_name
      )
      "#{base}?#{params}"
    end

    def default_receiving_account(payment_method)
      payment_method.active_receiving_accounts.first
    end
  end
end
