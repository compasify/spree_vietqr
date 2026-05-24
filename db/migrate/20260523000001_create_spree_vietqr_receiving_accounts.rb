# frozen_string_literal: true

class CreateSpreeVietqrReceivingAccounts < ActiveRecord::Migration[7.2]
  def change
    create_table :spree_vietqr_receiving_accounts do |t|
      t.references :payment_method, null: false, foreign_key: { to_table: :spree_payment_methods }
      t.string :provider, null: false
      t.string :bank_bin, null: false
      t.string :bank_name
      t.string :account_number, null: false
      t.string :account_name, null: false
      t.string :keyword_init, null: false, default: ''
      t.string :sub_account, null: false, default: ''
      t.string :virtual_account_number, null: false, default: ''
      t.boolean :active, null: false, default: true
      t.integer :priority, null: false, default: 0
      t.integer :routing_weight, null: false, default: 1
      t.bigint :monthly_quota_amount
      t.bigint :monthly_threshold_amount
      t.string :current_period, null: false
      t.bigint :period_allocated_amount, null: false, default: 0
      t.bigint :period_confirmed_amount, null: false, default: 0
      t.datetime :last_allocated_at
      t.string :webhook_secret
      t.string :payos_client_id
      t.string :payos_api_key
      t.string :payos_checksum_key
      t.jsonb :metadata, null: false, default: {}
      t.timestamps
    end

    add_index :spree_vietqr_receiving_accounts,
              %i[payment_method_id provider bank_bin account_number sub_account virtual_account_number keyword_init],
              unique: true,
              name: 'idx_vietqr_receiving_accounts_identity'
    add_index :spree_vietqr_receiving_accounts,
              %i[payment_method_id active priority],
              name: 'idx_vietqr_receiving_accounts_routing'
  end
end
