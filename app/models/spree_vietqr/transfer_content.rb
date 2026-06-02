# frozen_string_literal: true

module SpreeVietqr
  module TransferContent
    module_function

    def with_suffix(content)
      base = content.to_s.strip
      return base if base.blank?

      configured_suffix = suffix
      return base if configured_suffix.blank?
      return base if base.end_with?(" #{configured_suffix}") || base == configured_suffix

      "#{base} #{configured_suffix}"
    end

    def suffix
      ENV.fetch('VIETQR_TRANSFER_CONTENT_SUFFIX', '').to_s.strip
    end
  end
end
