# frozen_string_literal: true

require 'spec_helper'

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
    it 'has account_routing_strategy preference defaulting to single' do
      expect(payment_method.preferred_account_routing_strategy).to eq('single')
      expect(payment_method.account_routing_strategy).to eq('single')
    end
  end

  describe '.provider_options' do
    it 'lists supported provider choices for admin selection' do
      expect(described_class.provider_options).to include(['Xác nhận thủ công', 'manual'], ['Webhook SePay', 'sepay'], ['Webhook PayOS', 'payos'])
    end
  end

  describe '#custom_form_fields_partial_name' do
    it 'uses the VietQR admin custom fields partial' do
      expect(payment_method.custom_form_fields_partial_name).to eq('vietqr')
    end
  end

  describe '.routing_strategy_options' do
    it 'lists supported account routing strategies' do
      expect(described_class.routing_strategy_options).to include(['Fill first', 'single'], ['Theo hạn mức', 'quota_waterfall'])
    end
  end
end
