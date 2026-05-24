# frozen_string_literal: true

require 'spec_helper'

RSpec.describe SpreeVietqr::MatchTransaction do
  describe '.extract_order_code' do
    it 'extracts MMO order codes case-insensitively' do
      expect(described_class.extract_order_code('MMO R123456789 chuyen tien')).to eq('R123456789')
      expect(described_class.extract_order_code('mmo R999 test')).to eq('R999')
    end

    it 'extracts the first order code' do
      expect(described_class.extract_order_code('MMOR123 and MMOR456')).to eq('R123')
    end

    it 'extracts order codes with a receiving account keyword' do
      expect(described_class.extract_order_code('DHR123456789', keyword_init: 'DH')).to eq('R123456789')
      expect(described_class.extract_order_code('dj R999 test', keyword_init: 'DJ')).to eq('R999')
    end

    it 'returns nil when no order code is present' do
      expect(described_class.extract_order_code('random text')).to be_nil
      expect(described_class.extract_order_code(nil)).to be_nil
    end
  end

  describe '#account_matches?' do
    subject(:matcher) { described_class.new(payment_method: double('PaymentMethod')) }

    let(:allocation) do
      double(
        'SpreeVietqr::PaymentAllocation',
        account_number: '123456789',
        bank_bin: '970422',
        sub_account: 'branch-a',
        virtual_account_number: '987654321',
        payment_link_id: nil
      )
    end

    it 'rejects a transaction that omits an allocated sub-account' do
      transaction = SpreeVietqr::NormalizedTransaction.new(
        account_number: '123456789',
        bank_bin: '970422',
        virtual_account_number: '987654321'
      )

      expect(matcher.send(:account_matches?, allocation, transaction)).to be(false)
    end

    it 'rejects a transaction that omits an allocated virtual account number' do
      transaction = SpreeVietqr::NormalizedTransaction.new(
        account_number: '123456789',
        bank_bin: '970422',
        sub_account: 'branch-a'
      )

      expect(matcher.send(:account_matches?, allocation, transaction)).to be(false)
    end

    it 'accepts a transaction with all allocation account identifiers' do
      transaction = SpreeVietqr::NormalizedTransaction.new(
        account_number: '123456789',
        bank_bin: '970422',
        sub_account: 'BRANCH-A',
        virtual_account_number: '987654321'
      )

      expect(matcher.send(:account_matches?, allocation, transaction)).to be(true)
    end

    it 'accepts alphanumeric account numbers without stripping letters' do
      alpha_allocation = double(
        'SpreeVietqr::PaymentAllocation',
        account_number: 'VA-ABC123',
        bank_bin: '970422',
        sub_account: '',
        virtual_account_number: '',
        payment_link_id: nil
      )
      transaction = SpreeVietqr::NormalizedTransaction.new(
        account_number: 'va-abc123',
        bank_bin: '970422'
      )

      expect(matcher.send(:account_matches?, alpha_allocation, transaction)).to be(true)
    end

    it 'accepts a provider sub-account as the allocated account number' do
      virtual_account_allocation = double(
        'SpreeVietqr::PaymentAllocation',
        account_number: '96247HQTGZ',
        bank_bin: '970418',
        sub_account: '',
        virtual_account_number: '',
        payment_link_id: nil
      )
      transaction = SpreeVietqr::NormalizedTransaction.new(
        account_number: '8826225361',
        bank_bin: 'BIDV',
        sub_account: '96247HQTGZ'
      )

      expect(matcher.send(:account_matches?, virtual_account_allocation, transaction)).to be(true)
    end

    it 'rejects different alphanumeric account numbers with the same digits' do
      alpha_allocation = double(
        'SpreeVietqr::PaymentAllocation',
        account_number: 'VA123',
        bank_bin: '970422',
        sub_account: '',
        virtual_account_number: '',
        payment_link_id: nil
      )
      transaction = SpreeVietqr::NormalizedTransaction.new(
        account_number: 'VB123',
        bank_bin: '970422'
      )

      expect(matcher.send(:account_matches?, alpha_allocation, transaction)).to be(false)
    end

    it 'accepts a matching payment link id as a stronger PayOS reference' do
      payos_allocation = double('SpreeVietqr::PaymentAllocation', payment_link_id: 'link-123')
      transaction = SpreeVietqr::NormalizedTransaction.new(payment_link_id: 'link-123')

      expect(matcher.send(:account_matches?, payos_allocation, transaction)).to be(true)
    end

    it 'accepts an allocation scoped to the webhook-verified receiving account' do
      receiving_account = double('SpreeVietqr::ReceivingAccount', id: 1)
      matcher = described_class.new(payment_method: double('PaymentMethod'), receiving_account: receiving_account)
      scoped_allocation = double(
        'SpreeVietqr::PaymentAllocation',
        payment_link_id: nil,
        receiving_account_id: 1,
        account_number: 'different',
        bank_bin: '970418',
        sub_account: 'different',
        virtual_account_number: ''
      )
      transaction = SpreeVietqr::NormalizedTransaction.new(
        account_number: '8826225361',
        bank_bin: 'BIDV',
        sub_account: '96247HQTGZ'
      )

      expect(matcher.send(:account_matches?, scoped_allocation, transaction)).to be(true)
    end
  end

  describe '#amount_matches?' do
    subject(:matcher) { described_class.new(payment_method: double('PaymentMethod')) }

    it 'accepts exact payment amounts' do
      allocation = double('SpreeVietqr::PaymentAllocation', expected_amount: 2_000)
      transaction = SpreeVietqr::NormalizedTransaction.new(amount_cents: 2_000)

      expect(matcher.send(:amount_matches?, allocation, transaction)).to be(true)
    end

    it 'accepts mismatched amounts only for orders owned by a user' do
      allocation = double('SpreeVietqr::PaymentAllocation', expected_amount: 2_000, order: double('Spree::Order', user_id: 123))
      transaction = SpreeVietqr::NormalizedTransaction.new(amount_cents: 3_000)

      expect(matcher.send(:amount_matches?, allocation, transaction)).to be(true)
    end

    it 'rejects mismatched amounts for guest orders' do
      allocation = double('SpreeVietqr::PaymentAllocation', expected_amount: 2_000, order: double('Spree::Order', user_id: nil))
      transaction = SpreeVietqr::NormalizedTransaction.new(amount_cents: 3_000)

      expect(matcher.send(:amount_matches?, allocation, transaction)).to be(false)
    end
  end
end
