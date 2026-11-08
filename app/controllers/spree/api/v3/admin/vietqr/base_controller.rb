# frozen_string_literal: true

module Spree
  module Api
    module V3
      module Admin
        module Vietqr
          # Admin API for VietQR receiving accounts, allocations and webhook
          # events. Secret keys need `read_vietqr` / `write_vietqr`; staff are
          # authorized by their role's abilities on the same records.
          class BaseController < Spree::Api::V3::Admin::BaseController
            PER_PAGE_MAX = 100

            scoped_resource :vietqr

            private

            def store_payment_methods
              Spree::PaymentMethod::Vietqr.where(store_id: current_store.id)
            end

            def find_payment_method!(id)
              store_payment_methods.find_by_prefix_id!(id.to_s)
            end

            def page
              [params[:page].to_i, 1].max
            end

            def per_page
              value = params[:per_page].to_i
              value.positive? ? [value, PER_PAGE_MAX].min : 25
            end

            def render_page(scope)
              count = scope.count
              records = scope.offset((page - 1) * per_page).limit(per_page).to_a
              render json: {
                data: records.map { |record| serialize(record) },
                meta: { page: page, per_page: per_page, count: count, pages: (count.to_f / per_page).ceil }
              }
            end

            def render_validation_error(record)
              render_error(
                code: Spree::Api::V3::ErrorHandler::ERROR_CODES[:validation_error],
                message: record.errors.full_messages.to_sentence,
                status: :unprocessable_content,
                details: record.errors.to_hash
              )
            end

            def render_conflict(message)
              render_error(
                code: Spree::Api::V3::ErrorHandler::ERROR_CODES[:validation_error],
                message: message,
                status: :unprocessable_content
              )
            end

            def money(value)
              value&.to_i
            end

            def time(value)
              value&.iso8601
            end

            def serialize_allocation(allocation)
              {
                id: allocation.prefixed_id,
                status: allocation.status,
                provider: allocation.provider,
                order_number: allocation.order_number,
                order_id: allocation.order&.prefixed_id,
                payment_id: allocation.payment&.prefixed_id,
                payment_method_id: allocation.payment_method&.prefixed_id,
                receiving_account_id: allocation.receiving_account&.prefixed_id,
                bank_bin: allocation.bank_bin,
                account_number: allocation.account_number,
                account_name: allocation.account_name,
                expected_amount: money(allocation.expected_amount),
                transfer_content: allocation.transfer_content,
                expires_at: time(allocation.expires_at),
                confirmed_at: time(allocation.confirmed_at),
                released_at: time(allocation.released_at),
                release_reason: allocation.release_reason,
                created_at: time(allocation.created_at)
              }
            end
          end
        end
      end
    end
  end
end
