# frozen_string_literal: true

class CreateSpreeVietqrPaymentAllocations < ActiveRecord::Migration[7.2]
  def change
    create_table :spree_vietqr_payment_allocations do |t|
      t.references :payment, null: false, foreign_key: { to_table: :spree_payments }
      t.references :order, null: false, foreign_key: { to_table: :spree_orders }
      t.references :payment_method, null: false, foreign_key: { to_table: :spree_payment_methods }
      t.references :receiving_account, foreign_key: { to_table: :spree_vietqr_receiving_accounts }
      t.references :webhook_event, foreign_key: { to_table: :spree_vietqr_webhook_events }
      t.string :provider, null: false
      t.string :bank_bin, null: false
      t.string :account_number, null: false
      t.string :account_name, null: false
      t.string :sub_account, null: false, default: ''
      t.string :virtual_account_number, null: false, default: ''
      t.bigint :expected_amount, null: false
      t.string :transfer_content, null: false
      t.string :order_number, null: false
      t.string :provider_order_code
      t.string :payment_link_id
      t.string :provider_checkout_url
      t.text :provider_qr_code
      t.string :status, null: false, default: 'allocated'
      t.datetime :expires_at
      t.datetime :confirmed_at
      t.datetime :released_at
      t.string :release_reason
      t.jsonb :metadata, null: false, default: {}
      t.timestamps
    end

    add_foreign_key :spree_vietqr_webhook_events,
                    :spree_vietqr_receiving_accounts,
                    column: :receiving_account_id
    add_foreign_key :spree_vietqr_webhook_events,
                    :spree_vietqr_payment_allocations,
                    column: :payment_allocation_id

    add_index :spree_vietqr_payment_allocations,
              :payment_id,
              unique: true,
              where: 'released_at IS NULL',
              name: 'idx_vietqr_payment_allocations_active_payment'
    add_index :spree_vietqr_payment_allocations,
              %i[provider order_number status],
              name: 'idx_vietqr_payment_allocations_order_lookup'
    add_index :spree_vietqr_payment_allocations,
              %i[provider provider_order_code status],
              name: 'idx_vietqr_payment_allocations_provider_order_lookup'
    add_index :spree_vietqr_payment_allocations,
              %i[provider payment_link_id status],
              name: 'idx_vietqr_payment_allocations_payment_link_lookup'
    add_index :spree_vietqr_payment_allocations,
              %i[provider account_number bank_bin status],
              name: 'idx_vietqr_payment_allocations_account_lookup'
  end
end
