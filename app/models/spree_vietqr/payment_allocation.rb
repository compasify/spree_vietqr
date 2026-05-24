# frozen_string_literal: true

module SpreeVietqr
  class PaymentAllocation < ActiveRecord::Base
    self.table_name = 'spree_vietqr_payment_allocations'

    STATUSES = %w[allocated confirmed released].freeze

    belongs_to :payment, class_name: 'Spree::Payment'
    belongs_to :order, class_name: 'Spree::Order'
    belongs_to :payment_method, class_name: 'Spree::PaymentMethod::Vietqr'
    belongs_to :receiving_account, class_name: 'SpreeVietqr::ReceivingAccount', optional: true
    belongs_to :webhook_event, class_name: 'SpreeVietqr::WebhookEvent', optional: true

    scope :active, -> { where(released_at: nil) }
    scope :ordered_recently, -> { order(created_at: :desc) }

    before_validation :assign_defaults
    before_validation :normalize_identifiers

    validates :status, inclusion: { in: STATUSES }
    validates :provider, :bank_bin, :account_number, :account_name,
              :transfer_content, :order_number, presence: true
    validates :expected_amount, numericality: { only_integer: true, greater_than: 0 }

    def allocated?
      status == 'allocated'
    end

    def confirmed?
      status == 'confirmed'
    end

    def released?
      status == 'released'
    end

    private

    def assign_defaults
      self.status ||= 'allocated'
      self.provider ||= receiving_account&.provider
      self.order_number ||= order&.number
      self.expected_amount = expected_amount.to_i if expected_amount.present?
      self.sub_account = '' if sub_account.nil?
      self.virtual_account_number = '' if virtual_account_number.nil?
      self.metadata ||= {}
    end

    def normalize_identifiers
      self.bank_bin = AccountIdentifier.normalize_number(bank_bin)
      self.account_number = AccountIdentifier.normalize_account_number(account_number)
      self.sub_account = AccountIdentifier.normalize_text(sub_account)
      self.virtual_account_number = AccountIdentifier.normalize_number(virtual_account_number)
      self.provider_order_code = provider_order_code.to_s.presence
      self.payment_link_id = payment_link_id.to_s.presence
    end
  end
end
