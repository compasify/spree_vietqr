# frozen_string_literal: true

module Spree
  class PaymentMethod::Vietqr < Spree::PaymentMethod
    PROVIDERS = %w[manual sepay payos].freeze
    ROUTING_STRATEGIES = %w[single round_robin random quota_waterfall].freeze

    preference :account_routing_strategy, :string, default: 'single'

    has_many :receiving_accounts,
             class_name: 'SpreeVietqr::ReceivingAccount',
             foreign_key: :payment_method_id,
             dependent: :restrict_with_error,
             inverse_of: :payment_method
    has_many :payment_allocations,
             class_name: 'SpreeVietqr::PaymentAllocation',
             foreign_key: :payment_method_id,
             dependent: :nullify,
             inverse_of: :payment_method

    validate :validate_provider_preferences

    def self.provider_options
      [
        ['Xác nhận thủ công', 'manual'],
        ['Webhook SePay', 'sepay'],
        ['Webhook PayOS', 'payos']
      ]
    end

    def self.routing_strategy_options
      [
        ['Fill first', 'single'],
        ['Xoay vòng', 'round_robin'],
        ['Ngẫu nhiên', 'random'],
        ['Theo hạn mức', 'quota_waterfall']
      ]
    end

    def custom_form_fields_partial_name
      'vietqr'
    end

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

    def account_routing_strategy
      preferred_account_routing_strategy.to_s.presence || 'single'
    end

    def active_receiving_accounts
      receiving_accounts.active.ordered_for_routing
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

    def validate_provider_preferences
      errors.add(:preferred_account_routing_strategy, 'không được hỗ trợ') unless account_routing_strategy.in?(ROUTING_STRATEGIES)
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
