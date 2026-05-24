# frozen_string_literal: true

require 'openssl'

module SpreeVietqr
  module Providers
    class Sepay < Base
      TIMESTAMP_TOLERANCE = 300
      SIGNATURE_PREFIX = 'sha256='

      def verify!(request)
        signature = request.headers['X-SePay-Signature']
        timestamp = request.headers['X-SePay-Timestamp']

        raise VerificationError, 'Webhook secret is not configured' if webhook_secret.blank?
        raise VerificationError, 'Missing signature header' if signature.blank?
        raise VerificationError, 'Missing timestamp header' if timestamp.blank?
        raise VerificationError, 'Timestamp expired' if (Time.current.to_i - timestamp.to_i).abs > TIMESTAMP_TOLERANCE

        signed_content = "#{timestamp}.#{raw_body(request)}"
        expected = SIGNATURE_PREFIX + OpenSSL::HMAC.hexdigest('SHA256', webhook_secret.to_s, signed_content)
        raise VerificationError, 'Invalid signature' unless secure_compare(expected, signature)
      end

      def parse_transaction(payload)
        incoming = payload['transferType'].to_s.downcase == 'in'
        processable = incoming

        NormalizedTransaction.new(
          provider: 'sepay',
          provider_transaction_id: extract_transaction_id(payload),
          amount_cents: processable ? payload['transferAmount'].to_i : 0,
          order_code: processable ? extract_order_code(payload) : nil,
          account_number: payload['accountNumber'],
          bank_bin: payload['gateway'],
          sub_account: payload['subAccount'],
          raw_content: payload['content'],
          bank_reference: payload['referenceCode'],
          transaction_at: parse_time(payload['transactionDate']),
          metadata: {
            gateway: payload['gateway'],
            account_number: payload['accountNumber'],
            transfer_type: payload['transferType'],
            description: payload['description'],
            accumulated: payload['accumulated'],
            sub_account: payload['subAccount'],
            code: payload['code']
          }
        )
      end

      def extract_transaction_id(payload)
        payload['id']&.to_s
      end

      private

      def extract_order_code(payload)
        keyword_init = receiving_account&.keyword_init
        MatchTransaction.extract_order_code(payload['code'], keyword_init: keyword_init) ||
          MatchTransaction.extract_order_code(payload['content'], keyword_init: keyword_init)
      end

      def parse_time(value)
        return nil if value.blank?

        Time.zone.parse(value)
      rescue ArgumentError
        nil
      end

      def raw_body(request)
        request.env['spree_vietqr.raw_body'] || request.raw_post
      end

      def secure_compare(expected, actual)
        ActiveSupport::SecurityUtils.secure_compare(expected, actual)
      rescue ArgumentError
        false
      end
    end
  end
end
