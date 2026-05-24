# frozen_string_literal: true

module SpreeVietqr
  NormalizedTransaction = Struct.new(
    :provider,
    :provider_transaction_id,
    :amount_cents,
    :order_code,
    :account_number,
    :bank_bin,
    :sub_account,
    :virtual_account_number,
    :payment_link_id,
    :provider_order_code,
    :raw_content,
    :bank_reference,
    :transaction_at,
    :metadata,
    keyword_init: true
  ) do
    def amount_vnd
      amount_cents
    end
  end
end
