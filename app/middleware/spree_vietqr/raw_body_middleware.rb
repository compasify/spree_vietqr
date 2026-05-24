# frozen_string_literal: true

module SpreeVietqr
  class RawBodyMiddleware
    WEBHOOK_PATH_PREFIX = '/webhooks/payments'

    def initialize(app)
      @app = app
    end

    def call(env)
      if env['PATH_INFO']&.start_with?(WEBHOOK_PATH_PREFIX)
        body = env['rack.input'].read
        env['rack.input'].rewind
        env['spree_vietqr.raw_body'] = body
        env['RAW_POST_DATA'] = body
      end

      @app.call(env)
    end
  end
end
