# frozen_string_literal: true

require 'spec_helper'
require_relative '../../../app/services/spree_vietqr/resolve_webhook_credential'

RSpec.describe SpreeVietqr::ResolveWebhookCredential do
  class FakeCredentialProvider
    def initialize(payment_method:, receiving_account: nil)
      @payment_method = payment_method
      @receiving_account = receiving_account
    end

    def verify!(_request)
      return true if @receiving_account&.webhook_secret == 'shared-secret'

      raise SpreeVietqr::Providers::Base::VerificationError, 'invalid'
    end
  end

  class FakeAccountRelation < Array
    def active
      self
    end

    def for_provider(provider)
      self.class.new(select { |account| account.provider == provider })
    end

    def exists?
      any?
    end
  end

  let(:request) { double('Request') }

  before do
    vietqr_payment_method = payment_method
    Spree::PaymentMethod::Vietqr.define_singleton_method(:active) { [vietqr_payment_method] }
    allow(SpreeVietqr::Providers::Registry).to receive(:resolve).with('sepay').and_return(FakeCredentialProvider)
  end

  let(:payment_method) do
    double(
      'PaymentMethod',
      receiving_accounts: accounts,
      active_receiving_accounts: accounts
    )
  end

  context 'when more than one account verifies the same webhook credential' do
    let(:accounts) do
      FakeAccountRelation.new([
        double('Account 1', provider: 'sepay', webhook_secret: 'shared-secret', payos_checksum_key: nil),
        double('Account 2', provider: 'sepay', webhook_secret: 'shared-secret', payos_checksum_key: nil)
      ])
    end

    it 'does not scope matching to the first account' do
      credential = described_class.new(provider_name: 'sepay').call(request)

      expect(credential.payment_method).to eq(payment_method)
      expect(credential.receiving_account).to be_nil
      expect(credential.verification_receiving_account).to eq(accounts.first)
    end
  end

  context 'when exactly one account verifies the credential' do
    let(:accounts) do
      FakeAccountRelation.new([
        double('Account 1', provider: 'sepay', webhook_secret: 'shared-secret', payos_checksum_key: nil),
        double('Account 2', provider: 'sepay', webhook_secret: 'other-secret', payos_checksum_key: nil)
      ])
    end

    it 'scopes matching to that account' do
      credential = described_class.new(provider_name: 'sepay').call(request)

      expect(credential.receiving_account).to eq(accounts.first)
      expect(credential.verification_receiving_account).to be_nil
    end
  end
end
