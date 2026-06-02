# frozen_string_literal: true

require 'spec_helper'

RSpec.describe SpreeVietqr::TransferContent do
  describe '.with_suffix' do
    it 'returns the content unchanged when no suffix is configured' do
      expect(described_class.with_suffix('ATTNAPV4LRKNFE')).to eq('ATTNAPV4LRKNFE')
    end

    it 'appends the configured suffix with a single space' do
      allow(ENV).to receive(:fetch).with('VIETQR_TRANSFER_CONTENT_SUFFIX', '').and_return('SEVQR')

      expect(described_class.with_suffix('ATTNAPV4LRKNFE')).to eq('ATTNAPV4LRKNFE SEVQR')
    end

    it 'does not append the suffix twice' do
      allow(ENV).to receive(:fetch).with('VIETQR_TRANSFER_CONTENT_SUFFIX', '').and_return('SEVQR')

      expect(described_class.with_suffix('ATTNAPV4LRKNFE SEVQR')).to eq('ATTNAPV4LRKNFE SEVQR')
    end
  end
end
