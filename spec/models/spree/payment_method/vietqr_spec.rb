# frozen_string_literal: true

require 'spree_vietqr'

RSpec.describe Spree::PaymentMethod::Vietqr do
  subject(:payment_method) { described_class.new }

  describe '#method_type' do
    it 'returns vietqr' do
      expect(payment_method.method_type).to eq('vietqr')
    end
  end

  describe '#source_required?' do
    it 'returns false' do
      expect(payment_method.source_required?).to be false
    end
  end

  describe '#auto_capture?' do
    it 'returns false' do
      expect(payment_method.auto_capture?).to be false
    end
  end

  describe '#payment_source_class' do
    it 'returns nil' do
      expect(payment_method.payment_source_class).to be_nil
    end
  end

  describe 'preferences' do
    it 'has bank_bin preference' do
      payment_method.preferred_bank_bin = '970422'
      expect(payment_method.preferred_bank_bin).to eq('970422')
    end

    it 'has account_number preference' do
      payment_method.preferred_account_number = '0123456789'
      expect(payment_method.preferred_account_number).to eq('0123456789')
    end

    it 'has provider preference defaulting to manual' do
      expect(payment_method.preferred_provider).to eq('manual')
    end

    it 'has auto_confirm_grace_seconds preference defaulting to 60' do
      expect(payment_method.preferred_auto_confirm_grace_seconds).to eq(60)
    end
  end
end
