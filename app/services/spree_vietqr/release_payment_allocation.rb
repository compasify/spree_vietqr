# frozen_string_literal: true

module SpreeVietqr
  class ReleasePaymentAllocation
    def call(allocation:, reason:)
      ActiveRecord::Base.transaction do
        allocation.lock!
        return allocation if allocation.confirmed? || allocation.released?

        cancel_provider_payment_link!(allocation, reason)
        release_account_quota!(allocation)

        allocation.update!(
          status: 'released',
          released_at: Time.current,
          release_reason: reason
        )
      end

      allocation
    end

    private

    def cancel_provider_payment_link!(allocation, reason)
      return unless allocation.provider == 'payos'
      return if allocation.provider_order_code.blank?

      PayosClient.new(payment_method: allocation.payment_method, receiving_account: allocation.receiving_account).cancel_payment_link(allocation.provider_order_code, reason: reason)
    rescue StandardError => e
      Rails.logger.warn("[SpreeVietqr::ReleasePaymentAllocation] PayOS cancel failed for allocation #{allocation.id}: #{e.message}") if defined?(Rails)
      allocation.metadata = allocation.metadata.to_h.merge('payos_cancel_error' => e.message)
    end

    def release_account_quota!(allocation)
      account = allocation.receiving_account
      return unless account

      account.reset_period_if_needed!
      account.with_lock do
        account.update!(
          period_allocated_amount: [account.period_allocated_amount.to_i - allocation.expected_amount.to_i, 0].max
        )
      end
    end
  end
end
