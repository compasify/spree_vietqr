# frozen_string_literal: true

require 'spec_helper'

RSpec.describe SpreeVietqr::RawBodyMiddleware do
  it 'preserves raw body for webhook paths' do
    app = ->(env) { [200, {}, [env['spree_vietqr.raw_body']]] }
    env = { 'PATH_INFO' => '/webhooks/payments/sepay', 'rack.input' => StringIO.new('{"id":1}') }

    status, _headers, body = described_class.new(app).call(env)

    expect(status).to eq(200)
    expect(body).to eq(['{"id":1}'])
    expect(env['RAW_POST_DATA']).to eq('{"id":1}')
  end
end
