# frozen_string_literal: true

module SpreeVietqr
  class ExpireAllocationsJob < ActiveJob::Base
    queue_as :default

    def perform
      PaymentAllocation.active.where(status: 'allocated').where('expires_at < ?', Time.current).find_each do |allocation|
        next if payable_allocation?(allocation)

        ReleasePaymentAllocation.new.call(allocation: allocation, reason: 'expired')
      end
    end

    private

    def payable_allocation?(allocation)
      allocation.payment.state.in?(%w[checkout pending processing]) &&
        allocation.order.payment_state.in?(%w[balance_due pending checkout])
    end
  end
end
