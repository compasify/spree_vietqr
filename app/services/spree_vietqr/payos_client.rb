# frozen_string_literal: true

require 'json'
require 'net/http'
require 'openssl'
require 'uri'

module SpreeVietqr
  class PayosClient
    BASE_URL = 'https://api-merchant.payos.vn'

    def initialize(payment_method:, receiving_account: nil)
      @client_id = receiving_account&.payos_client_id
      @api_key = receiving_account&.payos_api_key
      @checksum_key = receiving_account&.payos_checksum_key
    end

    def create_payment_link(order:, return_url:, cancel_url:, description:, amount: nil)
      body = payment_link_body(order: order, amount: amount, return_url: return_url, cancel_url: cancel_url, description: description)
      body[:signature] = payment_link_signature(body)
      response = post('/v2/payment-requests', body)

      {
        bank_bin: response.dig('data', 'bin'),
        account_number: response.dig('data', 'accountNumber'),
        account_name: response.dig('data', 'accountName'),
        checkout_url: response.dig('data', 'checkoutUrl'),
        qr_code: response.dig('data', 'qrCode'),
        payment_link_id: response.dig('data', 'paymentLinkId'),
        provider_order_code: response.dig('data', 'orderCode')&.to_s,
        expires_at: parse_expiry(response.dig('data', 'expiredAt'))
      }
    end

    def get_payment_link(order_code)
      get("/v2/payment-requests/#{order_code}")
    end

    def cancel_payment_link(order_code, reason: nil)
      post("/v2/payment-requests/#{order_code}/cancel", { cancellationReason: reason })
    end

    private

    def payment_link_body(order:, return_url:, cancel_url:, description:, amount: nil)
      {
        orderCode: order.number.gsub(/\D/, '').to_i,
        amount: amount.to_i.nonzero? || order.total.to_i,
        description: description,
        returnUrl: return_url,
        cancelUrl: cancel_url,
        items: order.line_items.map { |line_item| { name: line_item.name, quantity: line_item.quantity, price: line_item.price.to_i } }
      }
    end

    def payment_link_signature(body)
      data = %i[amount cancelUrl description orderCode returnUrl]
             .map { |key| "#{key}=#{body[key]}" }
             .join('&')
      OpenSSL::HMAC.hexdigest('SHA256', @checksum_key.to_s, data)
    end

    def post(path, body)
      request(:post, path, body)
    end

    def get(path)
      request(:get, path)
    end

    def request(method, path, body = nil)
      uri = URI("#{BASE_URL}#{path}")
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = true
      http.open_timeout = 10
      http.read_timeout = 30

      request = method == :post ? Net::HTTP::Post.new(uri.path) : Net::HTTP::Get.new(uri.path)
      request['Content-Type'] = 'application/json'
      request['x-client-id'] = @client_id
      request['x-api-key'] = @api_key
      request.body = body.to_json if body

      parsed = JSON.parse(http.request(request).body)
      raise PayosApiError, "PayOS API error: #{parsed['desc']} (code: #{parsed['code']})" if parsed['code'].present? && parsed['code'] != '00'

      parsed
    end

    def parse_expiry(value)
      return nil if value.blank?

      Time.zone.at(value.to_i)
    end
  end

  class PayosApiError < StandardError; end
end
