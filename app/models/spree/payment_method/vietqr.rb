# frozen_string_literal: true

module Spree
  # Bank transfer by VietQR. Placing an order only records a pending payment;
  # the money is confirmed later by a provider webhook (SePay, PayOS) or by
  # staff, so this method never charges anything at checkout.
  class PaymentMethod::Vietqr < Spree::PaymentMethod
    PROVIDERS = %w[manual sepay payos].freeze
    ROUTING_STRATEGIES = %w[single round_robin random quota_waterfall].freeze
    PAYABLE_PAYMENT_STATUSES = %w[checkout pending processing].freeze
    # Order payment statuses after which no further transfer is expected.
    SETTLED_ORDER_PAYMENT_STATUSES = %w[paid overcharged refunded partially_refunded voided].freeze
    DEFAULT_TRANSFER_PREFIX = 'MMO'

    self.accepts_money_amounts = true

    preference :account_routing_strategy, :string, choices: ROUTING_STRATEGIES, default: 'single'
    # How long a QR (and its reserved account quota) stays valid, from the
    # moment it is first shown.
    preference :payment_timeout_minutes, :integer, default: 15
    # Transfer note prefix used when a receiving account has no keyword of its own.
    preference :transfer_content_prefix, :string, default: DEFAULT_TRANSFER_PREFIX

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

    validate :validate_payment_timeout

    def self.display_name
      'VietQR'
    end

    def self.description
      'Chuyển khoản ngân hàng bằng mã VietQR, đối soát tự động qua webhook SePay/PayOS hoặc xác nhận thủ công.'
    end

    def self.routing_strategy_options
      [
        ['Fill first', 'single'],
        ['Xoay vòng', 'round_robin'],
        ['Ngẫu nhiên', 'random'],
        ['Theo hạn mức', 'quota_waterfall']
      ]
    end

    def payment_source_class
      nil
    end

    def source_required?
      false
    end

    def session_required?
      false
    end

    # Money arrives by bank transfer, so there is never anything to charge
    # when the order is placed or dispatched.
    def resolved_capture_method
      'manual'
    end

    def method_type
      'vietqr'
    end

    def payment_icon_name
      'vietqr'
    end

    def actions
      %w[capture void]
    end

    def can_capture?(payment)
      payment.status.in?(%w[checkout pending])
    end

    def can_void?(payment)
      payment.status != 'void'
    end

    def account_routing_strategy
      preferred_account_routing_strategy.to_s.presence || 'single'
    end

    def payment_timeout_minutes
      value = preferred_payment_timeout_minutes.to_i
      value.positive? ? value : 15
    end

    def transfer_content_prefix
      preferred_transfer_content_prefix.to_s.strip.presence || DEFAULT_TRANSFER_PREFIX
    end

    def active_receiving_accounts
      receiving_accounts.active.ordered_for_routing
    end

    # Spree authorizes when the order is placed. A transfer has not happened
    # yet, so this only records a reference; the payment stays pending until a
    # webhook or staff confirms the money.
    def authorize(*)
      Spree::PaymentResponse.new(true, 'VietQR payment pending bank transfer', {}, authorization: generate_authorization_code)
    end

    def purchase(*)
      authorize
    end

    def capture(*)
      Spree::PaymentResponse.new(true, 'VietQR payment captured', {}, {})
    end

    def void(*)
      Spree::PaymentResponse.new(true, 'VietQR payment voided', {}, {})
    end

    def cancel(*, **)
      Spree::PaymentResponse.new(true, 'VietQR payment cancelled', {}, {})
    end

    def credit(*)
      Spree::PaymentResponse.new(true, 'VietQR payment refunded', {}, {})
    end

    private

    def generate_authorization_code
      "VIETQR-#{SecureRandom.hex(8).upcase}"
    end

    def validate_payment_timeout
      return if preferred_payment_timeout_minutes.blank? || preferred_payment_timeout_minutes.to_i.positive?

      errors.add(:preferred_payment_timeout_minutes, :greater_than, count: 0)
    end
  end
end
