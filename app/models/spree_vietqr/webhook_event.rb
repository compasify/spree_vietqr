# frozen_string_literal: true

module SpreeVietqr
  class WebhookEvent < ActiveRecord::Base
    self.table_name = 'spree_vietqr_webhook_events'

    belongs_to :payment, class_name: 'Spree::Payment', optional: true
    belongs_to :payment_method, class_name: 'Spree::PaymentMethod::Vietqr', optional: true
    belongs_to :receiving_account, class_name: 'SpreeVietqr::ReceivingAccount', optional: true
    belongs_to :payment_allocation, class_name: 'SpreeVietqr::PaymentAllocation', optional: true

    STATUSES = %w[received verified matched confirmed rejected unmatched duplicate error].freeze

    validates :provider, presence: true
    validates :status, inclusion: { in: STATUSES }

    scope :recent, -> { order(created_at: :desc) }
    scope :unmatched, -> { where(status: 'unmatched') }
    scope :for_provider, ->(provider) { where(provider: provider) }

    def duplicate?
      return false if provider_transaction_id.blank?

      self.class
          .where(provider: provider, provider_transaction_id: provider_transaction_id)
          .where.not(id: id)
          .where(status: %w[confirmed duplicate])
          .exists?
    end

    def mark_status!(new_status, error: nil)
      update!(
        status: new_status,
        error_message: error,
        processed_at: terminal_status?(new_status) ? Time.current : processed_at
      )
    end

    private

    def terminal_status?(status)
      status.in?(%w[confirmed rejected duplicate error])
    end
  end
end
