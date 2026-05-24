# frozen_string_literal: true

require 'spec_helper'
require_relative '../../../app/services/spree_vietqr/receiving_account_selector'

RSpec.describe SpreeVietqr::ReceivingAccountSelector do
  Account = Struct.new(:id, :priority, :eligible, :threshold, :last_allocated_at, keyword_init: true) do
    def reset_period_if_needed!
      self
    end

    def eligible_for_amount?(_amount)
      eligible
    end

    def threshold_reached?
      threshold
    end
  end

  def account(id:, priority:, eligible:, threshold: false, last_allocated_at: nil)
    Account.new(id: id, priority: priority, eligible: eligible, threshold: threshold, last_allocated_at: last_allocated_at)
  end

  let(:payment_method) { double('PaymentMethod', account_routing_strategy: strategy) }

  describe '#call' do
    context 'with fill first strategy' do
      let(:strategy) { 'single' }

      it 'skips full higher-priority accounts and selects the next eligible account' do
        full_primary = account(id: 1, priority: 0, eligible: false)
        next_account = account(id: 2, priority: 1, eligible: true)

        selected = described_class.new(payment_method: payment_method, amount: 100_000, accounts: [full_primary, next_account]).call

        expect(selected).to eq(next_account)
      end
    end

    context 'when every account is over quota' do
      let(:strategy) { 'round_robin' }

      it 'falls back to the first active account by priority so payment receiving is not blocked' do
        first_account = account(id: 2, priority: 0, eligible: false)
        later_account = account(id: 1, priority: 1, eligible: false)

        selected = described_class.new(payment_method: payment_method, amount: 100_000, accounts: [later_account, first_account]).call

        expect(selected).to eq(first_account)
      end
    end

    context 'with quota waterfall strategy' do
      let(:strategy) { 'quota_waterfall' }

      it 'prefers accounts below threshold before falling back to priority' do
        reached_threshold = account(id: 1, priority: 0, eligible: true, threshold: true)
        below_threshold = account(id: 2, priority: 1, eligible: true, threshold: false)

        selected = described_class.new(payment_method: payment_method, amount: 100_000, accounts: [reached_threshold, below_threshold]).call

        expect(selected).to eq(below_threshold)
      end
    end
  end
end
