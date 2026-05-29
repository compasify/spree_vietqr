# frozen_string_literal: true

require 'spec_helper'

RSpec.describe SpreeVietqr::AllocatePaymentAccount do
  subject(:allocator) do
    described_class.new(
      payment_method: double('PaymentMethod'),
      order: order,
      payment: double('Payment')
    )
  end

  let(:order) { double('Spree::Order', number: 'R123456789') }

  describe '#transfer_content' do
    it 'uses the receiving account keyword init when present' do
      account = double('ReceivingAccount', keyword_init: 'DH')

      expect(allocator.send(:transfer_content, account)).to eq('DHR123456789')
    end

    it 'falls back to MMO when the receiving account keyword init is blank' do
      account = double('ReceivingAccount', keyword_init: ' ')

      expect(allocator.send(:transfer_content, account)).to eq('MMOR123456789')
    end
  end

  describe '#refresh_existing_allocation!' do
    it 'updates an existing allocation to the current receiving account keyword' do
      account = double('ReceivingAccount', keyword_init: 'OSA')
      allocation = double(
        'SpreeVietqr::PaymentAllocation',
        receiving_account: account,
        transfer_content: 'MMOR123456789'
      )

      expect(allocation).to receive(:update!).with(transfer_content: 'OSAR123456789')

      expect(allocator.send(:refresh_existing_allocation!, allocation)).to eq(allocation)
    end

    it 'keeps an existing allocation when the transfer content is already current' do
      account = double('ReceivingAccount', keyword_init: 'OSA')
      allocation = double(
        'SpreeVietqr::PaymentAllocation',
        receiving_account: account,
        transfer_content: 'OSAR123456789'
      )

      expect(allocation).not_to receive(:update!)

      expect(allocator.send(:refresh_existing_allocation!, allocation)).to eq(allocation)
    end
  end

  describe '#release_replaced_allocations!' do
    let(:payment_method) { double('PaymentMethod') }
    let(:current_payment) { double('Spree::Payment', id: 42) }
    let(:payments_relation) { double('PaymentsRelation') }
    let(:stale_payments_scope) { double('StalePaymentsScope') }
    let(:where_chain) { double('WhereChain') }
    let(:replaced_payments) { double('ReplacedPayments') }
    let(:stale_payment) { double('Spree::Payment', can_void?: true) }
    let(:unvoidable_payment) { double('Spree::Payment', can_void?: false) }

    subject(:allocator) do
      described_class.new(
        payment_method: payment_method,
        order: order,
        payment: current_payment
      )
    end

    before do
      stub_const('SpreeVietqr::PaymentAllocation', Class.new do
        def self.active; end
      end)
      allocation_scope = double('AllocationScope').as_null_object
      allow(SpreeVietqr::PaymentAllocation).to receive(:active).and_return(allocation_scope)
      allow(allocation_scope).to receive(:where).with(order: order, payment_method: payment_method).and_return(allocation_scope)
      allow(allocation_scope).to receive(:where).and_return(allocation_scope)
      allow(allocation_scope).to receive(:find_each)

      allow(order).to receive(:payments).and_return(payments_relation)
      allow(payments_relation).to receive(:where)
        .with(payment_method: payment_method, state: SpreeVietqr::PaymentInfo::PAYABLE_PAYMENT_STATES)
        .and_return(stale_payments_scope)
      allow(stale_payments_scope).to receive(:where).with(no_args).and_return(where_chain)
      allow(where_chain).to receive(:not).with(id: 42).and_return(replaced_payments)
      allow(replaced_payments).to receive(:find_each).and_yield(stale_payment).and_yield(unvoidable_payment)
    end

    it 'voids older payable VietQR payments for the same order' do
      expect(stale_payment).to receive(:void!)
      expect(unvoidable_payment).not_to receive(:void!)

      allocator.send(:release_replaced_allocations!)
    end
  end
end
