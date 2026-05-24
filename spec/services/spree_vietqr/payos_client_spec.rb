# frozen_string_literal: true

require 'spec_helper'

RSpec.describe SpreeVietqr::PayosClient do
  let(:payment_method) { double('PaymentMethod') }
  let(:client) { described_class.new(payment_method: payment_method, receiving_account: receiving_account) }
  let(:receiving_account) do
    double(
      'ReceivingAccount',
      payos_client_id: 'account_client_id',
      payos_api_key: 'account_api_key',
      payos_checksum_key: 'account_checksum_key'
    )
  end
  let(:line_item) { double('LineItem', name: 'Product', quantity: 2, price: 10_000) }
  let(:order) { double('Order', number: 'R123456789', total: 20_000, line_items: [line_item]) }

  it 'builds a PayOS payment link body from a Spree order' do
    body = client.send(:payment_link_body, order: order, return_url: 'https://example.com/return', cancel_url: 'https://example.com/cancel', description: 'MMOR123456789')

    expect(body[:orderCode]).to eq(123_456_789)
    expect(body[:amount]).to eq(20_000)
    expect(body[:description]).to eq('MMOR123456789')
    expect(body[:items]).to eq([{ name: 'Product', quantity: 2, price: 10_000 }])
  end

  it 'signs the payment link payload in PayOS key order' do
    body = {
      orderCode: 123_456_789,
      amount: 20_000,
      description: 'MMOR123456789',
      returnUrl: 'https://example.com/return',
      cancelUrl: 'https://example.com/cancel'
    }
    expected_data = 'amount=20000&cancelUrl=https://example.com/cancel&description=MMOR123456789&orderCode=123456789&returnUrl=https://example.com/return'
    expected_signature = OpenSSL::HMAC.hexdigest('SHA256', 'account_checksum_key', expected_data)

    expect(client.send(:payment_link_signature, body)).to eq(expected_signature)
  end

  it 'uses receiving account credentials for signing' do
    body = {
      orderCode: 123_456_789,
      amount: 20_000,
      description: 'MMOR123456789',
      returnUrl: 'https://example.com/return',
      cancelUrl: 'https://example.com/cancel'
    }
    expected_data = 'amount=20000&cancelUrl=https://example.com/cancel&description=MMOR123456789&orderCode=123456789&returnUrl=https://example.com/return'
    expected_signature = OpenSSL::HMAC.hexdigest('SHA256', 'account_checksum_key', expected_data)

    expect(client.send(:payment_link_signature, body)).to eq(expected_signature)
  end
end
