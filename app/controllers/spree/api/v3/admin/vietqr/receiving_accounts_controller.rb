# frozen_string_literal: true

module Spree
  module Api
    module V3
      module Admin
        module Vietqr
          # Bank accounts a VietQR payment method routes transfers to. An
          # account that already received allocations is deactivated instead
          # of deleted, so past payments keep their snapshot.
          class ReceivingAccountsController < BaseController
            ATTRIBUTES = %i[
              provider bank_bin bank_name account_number account_name keyword_init sub_account
              virtual_account_number active priority routing_weight monthly_quota_amount
              monthly_threshold_amount payos_client_id
            ].freeze

            def index
              authorize! :read, SpreeVietqr::ReceivingAccount

              scope = store_scope
              scope = scope.where(payment_method: find_payment_method!(params[:payment_method_id])) if params[:payment_method_id].present?
              render_page(scope.includes(:payment_method).ordered_for_routing)
            end

            def show
              account = find_account!
              authorize! :read, account

              render json: serialize(account)
            end

            def create
              payment_method = find_payment_method!(params[:payment_method_id])
              account = payment_method.receiving_accounts.build(account_params)
              authorize! :create, account

              return render_validation_error(account) unless account.save

              render json: serialize(account), status: :created
            end

            def update
              account = find_account!
              authorize! :update, account

              return render_validation_error(account) unless account.update(account_params)

              render json: serialize(account)
            end

            def destroy
              account = find_account!
              authorize! :destroy, account

              if account.payment_allocations.exists?
                account.update!(active: false)
                render json: serialize(account)
              else
                account.destroy!
                head :no_content
              end
            end

            private

            def store_scope
              SpreeVietqr::ReceivingAccount.where(payment_method_id: store_payment_methods.select(:id))
            end

            def find_account!
              store_scope.find_by_prefix_id!(params[:id])
            end

            # A secret is only written when a new value is sent: blank keeps the
            # stored one, and the masked value read back is ignored.
            def account_params
              body = params.key?(:receiving_account) ? params.require(:receiving_account) : params
              attributes = body.permit(*ATTRIBUTES, *SpreeVietqr::ReceivingAccount::SECRET_ATTRIBUTES).to_h
              SpreeVietqr::ReceivingAccount::SECRET_ATTRIBUTES.each do |secret|
                value = attributes[secret.to_s].to_s
                attributes.delete(secret.to_s) if value.blank? || value.start_with?(SpreeVietqr::ReceivingAccount::SECRET_MASK)
              end
              attributes
            end

            def serialize(account)
              {
                id: account.prefixed_id,
                payment_method_id: account.payment_method.prefixed_id,
                provider: account.provider,
                bank_bin: account.bank_bin,
                bank_name: account.bank_name,
                account_number: account.account_number,
                account_name: account.account_name,
                keyword_init: account.keyword_init,
                sub_account: account.sub_account,
                virtual_account_number: account.virtual_account_number,
                active: account.active,
                priority: account.priority,
                routing_weight: account.routing_weight,
                monthly_quota_amount: money(account.monthly_quota_amount),
                monthly_threshold_amount: money(account.monthly_threshold_amount),
                current_period: account.current_period,
                period_allocated_amount: money(account.period_allocated_amount),
                period_confirmed_amount: money(account.period_confirmed_amount),
                last_allocated_at: time(account.last_allocated_at),
                payos_client_id: account.payos_client_id,
                webhook_secret: account.masked_secret(:webhook_secret),
                payos_api_key: account.masked_secret(:payos_api_key),
                payos_checksum_key: account.masked_secret(:payos_checksum_key),
                webhook_url: webhook_url(account),
                created_at: time(account.created_at),
                updated_at: time(account.updated_at)
              }
            end

            def webhook_url(account)
              return nil if account.provider == 'manual'

              "#{request.base_url}/webhooks/payments/#{account.provider}"
            end
          end
        end
      end
    end
  end
end
