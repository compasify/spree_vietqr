# frozen_string_literal: true

module SpreeVietqr
  module Providers
    class Registry
      class UnknownProviderError < StandardError; end

      class << self
        def register(name, klass)
          providers[name.to_s] = klass
        end

        def resolve(name)
          providers[name.to_s] || raise(UnknownProviderError, "Unknown provider: #{name}")
        end

        def registered?(name)
          providers.key?(name.to_s)
        end

        def all
          providers.dup
        end

        private

        def providers
          @providers ||= {}
        end
      end
    end
  end
end
