# frozen_string_literal: true

module SpreeVietqr
  class ReceivingAccount < ActiveRecord::Base
    self.table_name = 'spree_vietqr_receiving_accounts'

    belongs_to :payment_method, class_name: 'Spree::PaymentMethod::Vietqr'
    has_many :payment_allocations, class_name: 'SpreeVietqr::PaymentAllocation', dependent: :restrict_with_error

    scope :active, -> { where(active: true) }
    scope :ordered_for_routing, -> { order(priority: :asc, id: :asc) }
    scope :for_provider, ->(provider) { where(provider: provider.to_s) }

    before_validation :assign_defaults
    before_validation :normalize_identifiers

    validates :provider, :bank_bin, :account_number, :account_name, :current_period, presence: true
    validates :provider, inclusion: { in: Spree::PaymentMethod::Vietqr::PROVIDERS }
    validates :priority, numericality: { only_integer: true }
    validates :routing_weight, numericality: { only_integer: true, greater_than: 0 }
    validates :monthly_quota_amount, :monthly_threshold_amount,
              :period_allocated_amount, :period_confirmed_amount,
              numericality: { only_integer: true, greater_than_or_equal_to: 0 },
              allow_nil: true
    validate :provider_credentials_present

    def self.current_period_for(time = Time.current)
      time.strftime('%Y-%m')
    end

    def reset_period_if_needed!(now: Time.current)
      expected_period = self.class.current_period_for(now)
      return self if current_period == expected_period

      with_lock do
        next self if current_period == expected_period

        update!(
          current_period: expected_period,
          period_allocated_amount: 0,
          period_confirmed_amount: 0
        )
      end

      reload
    end

    def eligible_for_amount?(amount)
      amount = amount.to_i
      return true if monthly_quota_amount.blank? || monthly_quota_amount.to_i <= 0

      period_allocated_amount.to_i + amount <= monthly_quota_amount.to_i
    end

    def threshold_reached?
      monthly_threshold_amount.present? && period_allocated_amount.to_i >= monthly_threshold_amount.to_i
    end

    private

    def assign_defaults
      self.provider = 'manual' if provider.blank?
      self.priority = 0 if priority.nil?
      self.routing_weight = 1 if routing_weight.nil?
      self.active = true if active.nil?
      self.period_allocated_amount = 0 if period_allocated_amount.nil?
      self.period_confirmed_amount = 0 if period_confirmed_amount.nil?
      self.current_period = self.class.current_period_for if current_period.blank?
      self.keyword_init = keyword_init.to_s.strip
      self.sub_account = '' if sub_account.nil?
      self.virtual_account_number = '' if virtual_account_number.nil?
    end

    def normalize_identifiers
      self.bank_bin = AccountIdentifier.normalize_number(bank_bin)
      self.account_number = AccountIdentifier.normalize_account_number(account_number)
      self.sub_account = AccountIdentifier.normalize_text(sub_account)
      self.virtual_account_number = AccountIdentifier.normalize_number(virtual_account_number)
    end

    def provider_credentials_present
      case provider.to_s
      when 'sepay'
        errors.add(:webhook_secret, 'không được để trống cho SePay') if webhook_secret.blank?
      when 'payos'
        errors.add(:payos_client_id, 'không được để trống cho PayOS') if payos_client_id.blank?
        errors.add(:payos_api_key, 'không được để trống cho PayOS') if payos_api_key.blank?
        errors.add(:payos_checksum_key, 'không được để trống cho PayOS') if payos_checksum_key.blank?
      end
    end
  end
end
