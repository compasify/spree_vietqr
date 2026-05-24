# frozen_string_literal: true

module SpreeVietqr
  class MatchTransaction
    DEFAULT_TRANSFER_CONTENT_PREFIX = 'MMO'

    def initialize(payment_method:, receiving_account: nil)
      @payment_method = payment_method
      @receiving_account = receiving_account
    end

    def call(transaction)
      candidates = candidate_allocations(transaction)
      return nil if candidates.empty?

      candidates.find do |allocation|
        amount_matches?(allocation, transaction) &&
          account_matches?(allocation, transaction) &&
          payable_or_confirmed?(allocation)
      end
    end

    def self.extract_order_code(content, keyword_init: nil)
      prefixes = [DEFAULT_TRANSFER_CONTENT_PREFIX, keyword_init.to_s.strip.presence].compact
      pattern = /(?:#{prefixes.map { |prefix| Regexp.escape(prefix) }.join('|')})\s*(R\d+)/i

      content&.match(pattern)&.[](1)
    end

    private

    def candidate_allocations(transaction)
      scope = PaymentAllocation.where(payment_method: @payment_method, provider: transaction.provider).where.not(status: 'released')
      scope = scope.where(receiving_account: @receiving_account) if @receiving_account

      if transaction.payment_link_id.present?
        return scope.where(payment_link_id: transaction.payment_link_id).ordered_recently
      end

      if transaction.provider_order_code.present?
        matched = scope.where(provider_order_code: transaction.provider_order_code).ordered_recently
        return matched if matched.exists?
      end

      return PaymentAllocation.none if transaction.order_code.blank?

      scope.where(order_number: transaction.order_code).ordered_recently
    end

    def amount_matches?(allocation, transaction)
      actual_amount = transaction.amount_cents.to_i
      return true if allocation.expected_amount.to_i == actual_amount

      actual_amount.positive? && allocation.order&.user_id.present?
    end

    def account_matches?(allocation, transaction)
      return true if transaction.payment_link_id.present? && allocation.payment_link_id == transaction.payment_link_id
      return true if verified_receiving_account_allocation?(allocation)
      return false if transaction.account_number.blank? && transaction.virtual_account_number.blank? && transaction.sub_account.blank?

      matches_number = account_number_matches_transaction?(allocation, transaction)
      transaction_bank_bin = AccountIdentifier.normalize_number(transaction.bank_bin)
      matches_bank = transaction_bank_bin.blank? || compare_numeric_identifier(allocation.bank_bin, transaction.bank_bin)
      matches_sub_account = allocation.sub_account.blank? || (transaction.sub_account.present? && allocation.sub_account == AccountIdentifier.normalize_text(transaction.sub_account))
      matches_virtual_account = allocation.virtual_account_number.blank? || (transaction.virtual_account_number.present? && compare_numeric_identifier(allocation.virtual_account_number, transaction.virtual_account_number))

      matches_number && matches_bank && matches_sub_account && matches_virtual_account
    end

    def payable_or_confirmed?(allocation)
      return true if allocation.confirmed?

      payment = allocation.payment
      order = allocation.order
      return false unless payment.state.in?(%w[checkout pending processing])
      return true unless order.respond_to?(:payment_state)

      order.payment_state.in?(%w[balance_due pending checkout])
    end

    def compare_numeric_identifier(expected, actual)
      AccountIdentifier.normalize_number(expected) == AccountIdentifier.normalize_number(actual)
    end

    def account_number_matches_transaction?(allocation, transaction)
      [transaction.account_number, transaction.sub_account].compact.any? do |identifier|
        identifier.present? && AccountIdentifier.account_number_matches?(allocation.account_number, identifier)
      end
    end

    def verified_receiving_account_allocation?(allocation)
      @receiving_account && allocation.respond_to?(:receiving_account_id) && allocation.receiving_account_id == @receiving_account.id
    end
  end
end
