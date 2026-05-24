# frozen_string_literal: true

module SpreeVietqr
  class ReceivingAccountSelector
    def initialize(payment_method:, amount:, accounts: nil)
      @payment_method = payment_method
      @amount = amount.to_i
      @accounts = Array(accounts.presence || payment_method.active_receiving_accounts)
    end

    def call
      eligible_accounts = @accounts.select do |account|
        account.reset_period_if_needed!
        account.eligible_for_amount?(@amount)
      end

      return first_account if eligible_accounts.empty?

      case @payment_method.account_routing_strategy
      when 'random'
        eligible_accounts.sample
      when 'round_robin'
        eligible_accounts.min_by { |account| [account.last_allocated_at || Time.at(0), account.priority, account.id] }
      when 'quota_waterfall'
        preferred, overflow = eligible_accounts.partition { |account| !account.threshold_reached? }
        (preferred.presence || overflow).min_by { |account| [account.priority, account.id] }
      else
        eligible_accounts.min_by { |account| [account.priority, account.id] }
      end
    end

    private

    def first_account
      @accounts.min_by { |account| [account.priority, account.id] }
    end
  end
end
