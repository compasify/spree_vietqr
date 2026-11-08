# frozen_string_literal: true

module Spree
  module Api
    module V3
      module Admin
        module Vietqr
          # Stored bank webhooks: review them, match an unmatched transfer to an
          # order by hand, or process an event again.
          class WebhookEventsController < BaseController
            RESOLVABLE_STATUSES = %w[unmatched error].freeze

            def index
              authorize! :read, SpreeVietqr::WebhookEvent

              scope = store_scope
              scope = scope.where(provider: params[:provider]) if params[:provider].present?
              scope = scope.where(status: Array(params[:status])) if params[:status].present?
              if params[:q].present?
                term = "%#{SpreeVietqr::WebhookEvent.sanitize_sql_like(params[:q].to_s.strip)}%"
                scope = scope.where('provider_transaction_id ILIKE :term OR matched_order_number ILIKE :term OR parsed_order_code ILIKE :term',
                                    term: term)
              end
              render_page(scope.includes(:payment_method, :payment_allocation, :receiving_account).recent)
            end

            def show
              event = find_event!
              authorize! :read, event

              render json: serialize(event, detail: true)
            end

            def manual_match
              event = find_event!
              authorize! :update, event
              return render_conflict('Only an unmatched or failed event can be matched by hand') unless event.status.in?(RESOLVABLE_STATUSES)

              order = current_store.orders.find_by(number: params[:order_number].to_s.strip.upcase)
              result = SpreeVietqr::ManualMatchWebhookEvent.new(event: event, payment_method: payment_method_for(event)).call(order: order)
              return render_conflict(result.error) unless result.success?

              render json: serialize(event.reload, detail: true)
            end

            def retry_processing
              event = find_event!
              authorize! :update, event
              return render_conflict('Only an unmatched or failed event can be processed again') unless event.status.in?(RESOLVABLE_STATUSES)

              SpreeVietqr::RetryWebhookEvent.new(event: event, payment_method: payment_method_for(event)).call
              render json: serialize(event.reload, detail: true)
            end

            private

            # Events of this store's payment methods, plus events rejected or
            # unmatched before any payment method was resolved.
            def store_scope
              ids = store_payment_methods.select(:id)
              SpreeVietqr::WebhookEvent.where(payment_method_id: ids).or(SpreeVietqr::WebhookEvent.where(payment_method_id: nil))
            end

            def find_event!
              store_scope.find_by_prefix_id!(params[:id])
            end

            def payment_method_for(event)
              SpreeVietqr::ResolveEventPaymentMethod.call(event, scope: store_payment_methods)
            end

            def serialize(event, detail: false)
              data = {
                id: event.prefixed_id,
                provider: event.provider,
                status: event.status,
                provider_transaction_id: event.provider_transaction_id,
                amount: money(event.amount_cents),
                parsed_order_code: event.parsed_order_code,
                matched_order_number: event.matched_order_number,
                account_number: event.account_number,
                bank_bin: event.bank_bin,
                error_message: event.error_message,
                payment_method_id: event.payment_method&.prefixed_id,
                receiving_account_id: event.receiving_account&.prefixed_id,
                payment_allocation_id: event.payment_allocation&.prefixed_id,
                processed_at: time(event.processed_at),
                created_at: time(event.created_at)
              }
              return data unless detail

              data.merge(
                sub_account: event.sub_account,
                virtual_account_number: event.virtual_account_number,
                payment_link_id: event.payment_link_id,
                provider_order_code: event.provider_order_code,
                raw_payload: event.raw_payload,
                raw_headers: event.raw_headers,
                payment_allocation: event.payment_allocation && serialize_allocation(event.payment_allocation)
              )
            end
          end
        end
      end
    end
  end
end
