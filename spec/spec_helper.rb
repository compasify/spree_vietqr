# frozen_string_literal: true

require 'uri'

# Minimal stubs for standalone gem specs (no Rails boot)
# Don't require 'spree_vietqr' as it loads the Engine which needs Rails
module SpreeVietqr
  VERSION = '1.0.0' unless defined?(SpreeVietqr::VERSION)
end

module Spree
  class PaymentMethod; end
  class PaymentMethod::Vietqr < PaymentMethod; end
  class Order; end
end

# Load services directly
require_relative '../app/services/spree_vietqr/generate_qr'
require_relative '../app/services/spree_vietqr/payment_info'

RSpec.configure do |config|
  config.expect_with :rspec do |expectations|
    expectations.include_chain_clauses_in_custom_matcher_descriptions = true
  end

  config.mock_with :rspec do |mocks|
    mocks.verify_partial_doubles = true
  end
end
