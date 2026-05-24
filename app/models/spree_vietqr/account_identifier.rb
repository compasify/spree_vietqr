# frozen_string_literal: true

module SpreeVietqr
  module AccountIdentifier
    module_function

    def normalize_number(value)
      value.to_s.gsub(/\D/, '')
    end

    def normalize_account_number(value)
      value.to_s.strip.gsub(/\s+/, '')
    end

    def account_number_matches?(expected, actual)
      normalize_account_number(expected).casecmp?(normalize_account_number(actual))
    end

    def normalize_text(value)
      value.to_s.strip.downcase
    end
  end
end
