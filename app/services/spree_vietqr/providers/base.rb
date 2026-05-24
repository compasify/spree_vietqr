# frozen_string_literal: true

module SpreeVietqr
  module Providers
    class Base
      class VerificationError < StandardError; end
      class ParseError < StandardError; end

      attr_reader :payment_method, :receiving_account

      def initialize(payment_method:, receiving_account: nil)
        @payment_method = payment_method
        @receiving_account = receiving_account
      end

      def verify!(_request)
        raise NotImplementedError
      end

      def parse_transaction(_payload)
        raise NotImplementedError
      end

      def extract_transaction_id(_payload)
        raise NotImplementedError
      end

      def success_response
        { success: true }
      end

      def success_status
        200
      end

      protected

      def webhook_secret
        receiving_account&.webhook_secret
      end
    end
  end
end
