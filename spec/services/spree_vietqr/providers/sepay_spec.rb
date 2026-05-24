# frozen_string_literal: true

require 'spec_helper'

RSpec.describe SpreeVietqr::Providers::Sepay do
  let(:payment_method) { double('PaymentMethod') }
  let(:receiving_account) { double('ReceivingAccount', webhook_secret: 'test_secret_key', keyword_init: nil) }
  let(:provider) { described_class.new(payment_method: payment_method, receiving_account: receiving_account) }

  describe '#verify!' do
    let(:raw_body) { '{"id":123,"transferAmount":50000,"content":"MMOR123456789"}' }
    let(:timestamp) { Time.current.to_i.to_s }
    let(:signature) { 'sha256=' + OpenSSL::HMAC.hexdigest('SHA256', 'test_secret_key', "#{timestamp}.#{raw_body}") }
    let(:headers) { { 'X-SePay-Signature' => signature, 'X-SePay-Timestamp' => timestamp } }
    let(:request) { double('Request', headers: headers, env: { 'spree_vietqr.raw_body' => raw_body }, raw_post: raw_body) }

    it 'passes with a valid signature' do
      expect { provider.verify!(request) }.not_to raise_error
    end

    it 'raises with an invalid signature' do
      headers['X-SePay-Signature'] = 'sha256=invalid'
      expect { provider.verify!(request) }.to raise_error(SpreeVietqr::Providers::Base::VerificationError, /Invalid signature/)
    end

    it 'raises with an expired timestamp' do
      headers['X-SePay-Timestamp'] = (Time.current.to_i - 600).to_s
      expect { provider.verify!(request) }.to raise_error(SpreeVietqr::Providers::Base::VerificationError, /Timestamp expired/)
    end

    it 'raises when webhook secret is blank' do
      allow(receiving_account).to receive(:webhook_secret).and_return(nil)
      expect { provider.verify!(request) }.to raise_error(SpreeVietqr::Providers::Base::VerificationError, /not configured/)
    end
  end

  describe '#parse_transaction' do
    it 'normalizes the SePay payload' do
      tx = provider.parse_transaction(
        'id' => 92704,
        'gateway' => 'Vietcombank',
        'transactionDate' => '2024-07-02 11:08:33',
        'accountNumber' => '1017588888',
        'content' => 'MMO R123456789 chuyen tien',
        'transferType' => 'in',
        'transferAmount' => 50_000,
        'referenceCode' => 'FT24012345678',
        'code' => 'MMOR123456789'
      )

      expect(tx.provider).to eq('sepay')
      expect(tx.provider_transaction_id).to eq('92704')
      expect(tx.amount_cents).to eq(50_000)
      expect(tx.order_code).to eq('R123456789')
      expect(tx.bank_reference).to eq('FT24012345678')
    end

    it 'keeps the signed destination account for allocation matching' do
      tx = provider.parse_transaction(
        'id' => 92704,
        'accountNumber' => 'wrong',
        'content' => 'MMOR123456789',
        'transferType' => 'in',
        'transferAmount' => 50_000
      )

      expect(tx.order_code).to eq('R123456789')
      expect(tx.amount_cents).to eq(50_000)
      expect(tx.account_number).to eq('wrong')
    end

    it 'extracts order code with receiving account keyword init' do
      receiving_account = double('ReceivingAccount', keyword_init: 'DH', webhook_secret: 'test_secret_key')
      provider = described_class.new(payment_method: payment_method, receiving_account: receiving_account)

      tx = provider.parse_transaction(
        'id' => 92704,
        'content' => 'DHR123456789',
        'transferType' => 'in',
        'transferAmount' => 50_000
      )

      expect(tx.order_code).to eq('R123456789')
    end
  end
end
