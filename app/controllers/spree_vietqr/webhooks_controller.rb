# frozen_string_literal: true

module SpreeVietqr
  class WebhooksController < ActionController::API
    def receive
      provider_name = params[:provider].to_s
      return render(json: { error: 'Unknown provider' }, status: :not_found) unless Providers::Registry.registered?(provider_name)

      credential = ResolveWebhookCredential.new(provider_name: provider_name).call(request)
      unless credential
        store_rejected_event(provider_name)
        return render(json: { error: 'Unauthorized' }, status: :unauthorized)
      end

      result = ProcessWebhook.new(
        provider_name: provider_name,
        payment_method: credential.payment_method,
        receiving_account: credential.receiving_account,
        verification_receiving_account: credential.verification_receiving_account
      ).call(request)
      render json: result[:body], status: result[:status]
    end

    private

    def store_rejected_event(provider_name)
      WebhookEvent.create!(
        provider: provider_name,
        raw_payload: parse_body,
        raw_headers: extract_headers,
        status: 'rejected',
        error_message: 'No configured webhook credential verified this request',
        processed_at: Time.current
      )
    end

    def parse_body
      JSON.parse(raw_body).with_indifferent_access
    rescue JSON::ParserError
      {}
    end

    def extract_headers
      request.headers.to_h
             .select { |key, _| key.start_with?('HTTP_') || key.in?(%w[CONTENT_TYPE CONTENT_LENGTH]) }
             .except('HTTP_AUTHORIZATION', 'HTTP_COOKIE', 'HTTP_X_CSRF_TOKEN')
    end

    def raw_body
      request.env['spree_vietqr.raw_body'] || request.raw_post
    end
  end
end
