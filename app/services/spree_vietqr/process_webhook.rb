# frozen_string_literal: true

module SpreeVietqr
  class ProcessWebhook
    def initialize(provider_name:, payment_method:, receiving_account: nil, verification_receiving_account: nil)
      @provider_name = provider_name.to_s
      @payment_method = payment_method
      @receiving_account = receiving_account
      @verification_receiving_account = verification_receiving_account || receiving_account
      @provider = Providers::Registry.resolve(@provider_name).new(payment_method: payment_method, receiving_account: @verification_receiving_account)
    end

    def call(request)
      payload = parse_body(request)
      event = store_raw_event(payload, request)

      begin
        @provider.verify!(request)
        event.mark_status!('verified')
      rescue Providers::Base::VerificationError => e
        event.mark_status!('rejected', error: e.message)
        return { status: 401, body: { error: 'Unauthorized' } }
      end

      if event.duplicate?
        event.mark_status!('duplicate')
        return success_result
      end

      transaction = @provider.parse_transaction(payload)
      event.update!(
        amount_cents: transaction.amount_cents,
        parsed_order_code: transaction.order_code,
        account_number: transaction.account_number,
        bank_bin: transaction.bank_bin,
        sub_account: transaction.sub_account,
        virtual_account_number: transaction.virtual_account_number,
        payment_link_id: transaction.payment_link_id,
        provider_order_code: transaction.provider_order_code
      )

      allocation = MatchTransaction.new(payment_method: @payment_method, receiving_account: @receiving_account).call(transaction)
      unless allocation
        event.mark_status!('unmatched')
        return success_result
      end

      event.update!(
        matched_order_number: allocation.order_number,
        payment_allocation: allocation,
        receiving_account: allocation.receiving_account,
        status: 'matched'
      )
      confirmed = ConfirmPayment.new(payment_method: @payment_method).call(allocation: allocation, webhook_event: event)
      return { status: 500, body: { error: 'Payment confirmation failed' } } if !confirmed && event.reload.status == 'error'

      success_result
    rescue StandardError => e
      event&.mark_status!('error', error: e.message)
      Rails.logger.error("[SpreeVietqr::ProcessWebhook] #{e.class}: #{e.message}") if defined?(Rails)
      { status: 500, body: { error: 'Webhook processing failed' } }
    end

    private

    def parse_body(request)
      JSON.parse(raw_body(request)).with_indifferent_access
    rescue JSON::ParserError
      {}
    end

    def store_raw_event(payload, request)
      WebhookEvent.create!(
        provider: @provider_name,
        payment_method: @payment_method,
        provider_transaction_id: @provider.extract_transaction_id(payload),
        raw_payload: payload,
        raw_headers: extract_headers(request),
        receiving_account: @receiving_account,
        status: 'received'
      )
    end

    def extract_headers(request)
      request.headers.to_h
             .select { |key, _| key.start_with?('HTTP_') || key.in?(%w[CONTENT_TYPE CONTENT_LENGTH]) }
             .except('HTTP_AUTHORIZATION', 'HTTP_COOKIE', 'HTTP_X_CSRF_TOKEN')
    end

    def raw_body(request)
      request.env['spree_vietqr.raw_body'] || request.raw_post
    end

    def success_result
      { status: @provider.success_status, body: @provider.success_response }
    end
  end
end
