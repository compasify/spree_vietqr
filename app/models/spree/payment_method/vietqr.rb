# frozen_string_literal: true

module Spree
  class PaymentMethod::Vietqr < Spree::PaymentMethod
    preference :bank_bin, :string
    preference :account_number, :string
    preference :account_name, :string
    preference :provider, :string, default: 'manual'
    preference :webhook_secret, :string
    preference :auto_confirm_grace_seconds, :integer, default: 60

    def payment_source_class
      nil
    end

    def source_required?
      false
    end

    def auto_capture?
      false
    end

    def method_type
      'vietqr'
    end

    # Spree calls authorize when completing an order. For VietQR (bank transfer),
    # we return success immediately — actual payment confirmation happens later
    # via webhook or manual admin action.
    def authorize(_amount, _source, _options = {})
      GatewayResponse.new(
        true,
        'VietQR payment pending bank transfer',
        authorization: generate_authorization_code
      )
    end

    def capture(_amount, _authorization, _options = {})
      GatewayResponse.new(true, 'VietQR payment captured')
    end

    def void(_authorization, _options = {})
      GatewayResponse.new(true, 'VietQR payment voided')
    end

    def cancel(_authorization)
      GatewayResponse.new(true, 'VietQR payment cancelled')
    end

    private

    def generate_authorization_code
      "VIETQR-#{SecureRandom.hex(8).upcase}"
    end

    # Minimal response object compatible with Spree::Payment::Processing#gateway_action.
    # Quacks like ActiveMerchant::Billing::Response without requiring the gem.
    class GatewayResponse
      attr_reader :message, :params

      def initialize(success, message, params = {})
        @success = success
        @message = message
        @params = params
      end

      def success?
        @success
      end

      def authorization
        @params[:authorization] || ''
      end

      def avs_result
        { 'code' => nil }
      end

      def cvv_result
        { 'code' => nil }
      end

      def to_s
        message
      end
    end
  end
end
