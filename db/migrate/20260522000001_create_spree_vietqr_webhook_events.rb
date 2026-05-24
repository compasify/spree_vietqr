# frozen_string_literal: true

class CreateSpreeVietqrWebhookEvents < ActiveRecord::Migration[7.2]
  def change
    create_table :spree_vietqr_webhook_events do |t|
      t.string :provider, null: false, index: true
      t.string :provider_transaction_id, index: true
      t.string :status, null: false, default: 'received'
      t.jsonb :raw_payload, null: false, default: {}
      t.jsonb :raw_headers, default: {}
      t.references :receiving_account, null: true, index: true
      t.references :payment_allocation, null: true, index: true
      t.string :matched_order_number
      t.references :payment_method, foreign_key: { to_table: :spree_payment_methods }, null: true
      t.references :payment, foreign_key: { to_table: :spree_payments }, null: true
      t.bigint :amount_cents
      t.string :parsed_order_code
      t.string :account_number
      t.string :bank_bin
      t.string :sub_account
      t.string :virtual_account_number
      t.string :payment_link_id
      t.string :provider_order_code
      t.string :error_message
      t.datetime :processed_at
      t.timestamps
    end

    add_index :spree_vietqr_webhook_events,
              %i[provider provider_transaction_id],
              where: 'provider_transaction_id IS NOT NULL',
              name: 'idx_webhook_events_provider_tx_id'
  end
end
