# frozen_string_literal: true

require 'openssl'

module SpreeVietqr
  module Providers
    class Payos < Base
      def verify!(request)
        payload = parse_payload(request)
        data = payload['data']
        signature = payload['signature']

        raise VerificationError, 'PayOS checksum key is not configured' if checksum_key.blank?
        raise VerificationError, 'Missing data in webhook' if data.blank?
        raise VerificationError, 'Missing signature in webhook' if signature.blank?
        raise VerificationError, 'Invalid signature' unless secure_compare(compute_signature(data), signature)
      end

      def parse_transaction(payload)
        data = payload['data'] || {}
        successful = data['code'].to_s == '00'

        NormalizedTransaction.new(
          provider: 'payos',
          provider_transaction_id: extract_transaction_id(payload),
          amount_cents: successful ? data['amount'].to_i : 0,
          order_code: successful ? reconstruct_order_number(data['orderCode']) : nil,
          account_number: data['accountNumber'],
          virtual_account_number: data['virtualAccountNumber'],
          payment_link_id: data['paymentLinkId'],
          provider_order_code: data['orderCode']&.to_s,
          raw_content: data['description'],
          bank_reference: data['reference'],
          transaction_at: parse_time(data['transactionDateTime']),
          metadata: {
            payment_link_id: data['paymentLinkId'],
            code: data['code'],
            desc: data['desc'],
            currency: data['currency'],
            counter_account_bank_id: data['counterAccountBankId'],
            counter_account_bank_name: data['counterAccountBankName'],
            counter_account_name: data['counterAccountName'],
            counter_account_number: data['counterAccountNumber'],
            virtual_account_name: data['virtualAccountName'],
            virtual_account_number: data['virtualAccountNumber']
          }
        )
      end

      def extract_transaction_id(payload)
        data = payload['data']
        return nil unless data

        data['reference'] || data['paymentLinkId'] || data['orderCode']&.to_s
      end

      private

      def parse_payload(request)
        JSON.parse(request.env['spree_vietqr.raw_body'] || request.raw_post).with_indifferent_access
      rescue JSON::ParserError
        raise VerificationError, 'Invalid JSON body'
      end

      def compute_signature(data)
        data.keys.sort.map do |key|
          value = data[key]
          value = normalize_signature_value(value)
          "#{key}=#{value}"
        end.join('&').then do |data_string|
          OpenSSL::HMAC.hexdigest('SHA256', checksum_key.to_s, data_string)
        end
      end

      def normalize_signature_value(value)
        return '' if value.nil?
        return value.map { |item| item.is_a?(Hash) ? item.sort.to_h : item }.to_json if value.is_a?(Array)

        value
      end

      def checksum_key
        receiving_account&.payos_checksum_key
      end

      def reconstruct_order_number(order_code)
        return nil if order_code.blank?

        "R#{order_code}"
      end

      def parse_time(value)
        return nil if value.blank?

        Time.zone.parse(value)
      rescue ArgumentError
        nil
      end

      def secure_compare(expected, actual)
        ActiveSupport::SecurityUtils.secure_compare(expected, actual)
      rescue ArgumentError
        false
      end
    end
  end
end
