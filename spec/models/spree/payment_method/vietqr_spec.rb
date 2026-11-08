# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Spree::PaymentMethod::Vietqr do
  subject(:payment_method) { described_class.new }

  describe '#method_type' do
    it 'returns vietqr' do
      expect(payment_method.method_type).to eq('vietqr')
    end
  end

  describe '#payment_icon_name' do
    it 'uses the VietQR payment icon' do
      expect(payment_method.payment_icon_name).to eq('vietqr')
    end
  end

  describe '#source_required?' do
    it 'returns false' do
      expect(payment_method.source_required?).to be false
    end
  end

  describe '#resolved_capture_method' do
    it 'never captures at checkout' do
      expect(payment_method.resolved_capture_method).to eq('manual')
    end
  end

  describe '#session_required?' do
    it 'returns false' do
      expect(payment_method.session_required?).to be false
    end
  end

  describe '#authorize' do
    it 'succeeds with a VietQR reference without moving money' do
      response = payment_method.authorize(Object.new, nil)

      expect(response).to be_success
      expect(response.authorization).to start_with('VIETQR-')
    end
  end

  describe '#payment_source_class' do
    it 'returns nil' do
      expect(payment_method.payment_source_class).to be_nil
    end
  end

  describe 'preferences' do
    it 'has account_routing_strategy preference defaulting to single' do
      expect(payment_method.preferred_account_routing_strategy).to eq('single')
      expect(payment_method.account_routing_strategy).to eq('single')
    end

    it 'defaults the QR timeout and transfer prefix' do
      expect(payment_method.payment_timeout_minutes).to eq(15)
      expect(payment_method.transfer_content_prefix).to eq('MMO')
    end

    it 'uses a configured transfer prefix' do
      payment_method.preferred_transfer_content_prefix = ' PV '

      expect(payment_method.transfer_content_prefix).to eq('PV')
    end
  end

  describe 'PROVIDERS' do
    it 'lists the supported confirmation providers' do
      expect(described_class::PROVIDERS).to eq(%w[manual sepay payos])
    end
  end

  describe '.routing_strategy_options' do
    it 'lists supported account routing strategies' do
      expect(described_class.routing_strategy_options).to include(['Fill first', 'single'], ['Theo hạn mức', 'quota_waterfall'])
    end
  end
end
