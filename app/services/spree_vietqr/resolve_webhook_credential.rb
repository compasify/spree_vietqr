# frozen_string_literal: true

module SpreeVietqr
  class ResolveWebhookCredential
    ResolvedCredential = Struct.new(:payment_method, :receiving_account, :verification_receiving_account, keyword_init: true)

    def initialize(provider_name:)
      @provider_name = provider_name.to_s
      @provider_class = Providers::Registry.resolve(@provider_name)
    end

    def call(request)
      eligible_payment_methods.each do |payment_method|
        verified_contexts = credential_contexts_for(payment_method).select { |context| verified?(request, context) }
        next if verified_contexts.empty?

        account_contexts = verified_contexts.select(&:receiving_account)
        return account_contexts.first if account_contexts.one?

        verification_context = account_contexts.first || verified_contexts.first
        return ResolvedCredential.new(
          payment_method: payment_method,
          receiving_account: nil,
          verification_receiving_account: verification_context.receiving_account
        )
      end

      nil
    end

    private

    def eligible_payment_methods
      Spree::PaymentMethod::Vietqr.active.select do |payment_method|
        payment_method.receiving_accounts.active.for_provider(@provider_name).exists?
      end
    end

    def credential_contexts_for(payment_method)
      contexts = []

      payment_method.active_receiving_accounts.for_provider(@provider_name).each do |account|
        next if account.webhook_secret.blank? && account.payos_checksum_key.blank?

        contexts << ResolvedCredential.new(payment_method: payment_method, receiving_account: account)
      end

      contexts
    end

    def verified?(request, context)
      provider = @provider_class.new(payment_method: context.payment_method, receiving_account: context.receiving_account)
      provider.verify!(request)
      true
    rescue Providers::Base::VerificationError
      false
    end

  end
end
