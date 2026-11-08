# frozen_string_literal: true

module Spree
  module Api
    module V3
      module Store
        # GET /api/v3/store/orders/:id/vietqr
        #
        # The QR and bank details a customer needs to pay a placed order by
        # VietQR, or its confirmed state once the transfer was matched. Poll it
        # to learn when the payment lands. Guests authorize with the order
        # token, signed-in customers with their JWT.
        class VietqrPaymentsController < Store::BaseController
          def show
            order = find_order!
            summary = SpreeVietqr::OrderPaymentSummary.call(order: order, request_base_url: request.base_url)
            return render_unavailable('This order has no pending VietQR payment') if summary.nil?

            render json: summary
          rescue ActiveRecord::RecordNotFound => e
            raise if e.model == Spree::Order.name

            render_unavailable(e.message)
          rescue SpreeVietqr::PayosApiError => e
            render_error(code: Spree::Api::V3::ErrorHandler::ERROR_CODES[:processing_error] || 'processing_error',
                         message: e.message, status: :bad_gateway)
          end

          private

          def find_order!
            scope = storefront_access_policy.scope(current_store.orders.complete, token: order_token)
            scope.find_by_prefix_id(params[:id]) || scope.find_by(number: params[:id].to_s.upcase) ||
              raise(ActiveRecord::RecordNotFound.new(nil, Spree::Order.name))
          end

          def render_unavailable(message)
            render_error(code: Spree::Api::V3::ErrorHandler::ERROR_CODES[:validation_error], message: message,
                         status: :unprocessable_content)
          end
        end
      end
    end
  end
end
