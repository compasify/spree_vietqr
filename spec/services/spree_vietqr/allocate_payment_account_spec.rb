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
end
