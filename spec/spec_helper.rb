# frozen_string_literal: true

require 'uri'
require 'json'
require 'stringio'
require 'active_support'
require 'active_support/core_ext'
require 'active_support/security_utils'

Time.zone = 'UTC'

# Minimal stubs for standalone gem specs (no Rails boot)
# Don't require 'spree_vietqr' as it loads the Engine which needs Rails
module SpreeVietqr
  VERSION = '1.0.0' unless defined?(SpreeVietqr::VERSION)
end

module Spree
  class PaymentMethod
    def self.preference(name, _type, default: nil)
      define_method("preferred_#{name}") do
        preference_values.fetch(name, default)
      end

      define_method("preferred_#{name}=") do |value|
        preference_values[name] = value
      end
    end

    def self.validate(*); end
    def self.before_validation(*); end
    def self.has_many(*); end

    def preference_values
      @preference_values ||= {}
    end
  end
  class PaymentMethod::Vietqr < PaymentMethod; end
  class Order; end
end

# Load services directly
require_relative '../app/models/spree_vietqr/account_identifier'
require_relative '../app/models/spree_vietqr/normalized_transaction'
require_relative '../app/services/spree_vietqr/providers/base'
require_relative '../app/services/spree_vietqr/providers/registry'
require_relative '../app/services/spree_vietqr/match_transaction'
require_relative '../app/services/spree_vietqr/providers/sepay'
require_relative '../app/services/spree_vietqr/providers/payos'
require_relative '../app/services/spree_vietqr/payos_client'
require_relative '../app/middleware/spree_vietqr/raw_body_middleware'
require_relative '../app/models/spree/payment_method/vietqr'
require_relative '../app/services/spree_vietqr/generate_qr'
require_relative '../app/services/spree_vietqr/allocate_payment_account'
require_relative '../app/services/spree_vietqr/payment_info'

RSpec.configure do |config|
  config.expect_with :rspec do |expectations|
    expectations.include_chain_clauses_in_custom_matcher_descriptions = true
  end

  config.mock_with :rspec do |mocks|
    mocks.verify_partial_doubles = true
  end
end
