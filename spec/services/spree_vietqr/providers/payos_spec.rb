# frozen_string_literal: true

require 'spec_helper'

RSpec.describe SpreeVietqr::Providers::Payos do
  let(:payment_method) { double('PaymentMethod') }
  let(:receiving_account) { double('ReceivingAccount', payos_checksum_key: 'test_checksum_key') }
  let(:provider) { described_class.new(payment_method: payment_method, receiving_account: receiving_account) }
  let(:data) do
    {
      'amount' => 50_000,
      'description' => 'MMOR123456789',
      'orderCode' => 123_456_789,
      'paymentLinkId' => 'abc123',
      'reference' => 'TF230204212323',
      'transactionDateTime' => '2024-01-01 12:00:00',
      'code' => '00',
      'accountNumber' => '123456789',
      'virtualAccountNumber' => '987654321'
    }
  end
  let(:signature) do
    data.keys.sort.map { |key| "#{key}=#{data[key]}" }.join('&').then do |content|
      OpenSSL::HMAC.hexdigest('SHA256', 'test_checksum_key', content)
    end
  end
  let(:payload) { { 'data' => data, 'signature' => signature, 'code' => '00', 'success' => true } }
  let(:raw_body) { payload.to_json }
  let(:request) { double('Request', env: { 'spree_vietqr.raw_body' => raw_body }, raw_post: raw_body) }

  describe '#verify!' do
    it 'passes with a valid signature' do
      expect { provider.verify!(request) }.not_to raise_error
    end

    it 'raises with tampered data' do
      payload['data']['amount'] = 99_999
      expect { provider.verify!(request) }.to raise_error(SpreeVietqr::Providers::Base::VerificationError, /Invalid signature/)
    end

    it 'raises when checksum key is blank' do
      allow(receiving_account).to receive(:payos_checksum_key).and_return(nil)
      expect { provider.verify!(request) }.to raise_error(SpreeVietqr::Providers::Base::VerificationError, /not configured/)
    end

    it 'can verify with a receiving account checksum key' do
      account = double('ReceivingAccount', payos_checksum_key: 'account_checksum_key')
      account_data = data.dup
      account_signature = account_data.keys.sort.map { |key| "#{key}=#{account_data[key]}" }.join('&').then do |content|
        OpenSSL::HMAC.hexdigest('SHA256', 'account_checksum_key', content)
      end
      account_payload = { 'data' => account_data, 'signature' => account_signature }
      account_request = double('Request', env: { 'spree_vietqr.raw_body' => account_payload.to_json }, raw_post: account_payload.to_json)
      account_provider = described_class.new(payment_method: payment_method, receiving_account: account)

      expect { account_provider.verify!(account_request) }.not_to raise_error
    end
  end

  describe '#parse_transaction' do
    it 'normalizes the PayOS payload' do
      tx = provider.parse_transaction(payload)

      expect(tx.provider).to eq('payos')
      expect(tx.provider_transaction_id).to eq('TF230204212323')
      expect(tx.amount_cents).to eq(50_000)
      expect(tx.order_code).to eq('R123456789')
      expect(tx.account_number).to eq('123456789')
      expect(tx.virtual_account_number).to eq('987654321')
      expect(tx.payment_link_id).to eq('abc123')
    end

    it 'uses signed data code instead of unsigned top-level success' do
      payload['success'] = false

      tx = provider.parse_transaction(payload)

      expect(tx.amount_cents).to eq(50_000)
      expect(tx.order_code).to eq('R123456789')
    end
  end
end
