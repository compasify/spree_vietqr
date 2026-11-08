# frozen_string_literal: true

module Spree
  module Api
    module V3
      module Admin
        module Vietqr
          # QR allocations of the store's VietQR payment methods, newest first.
          class PaymentAllocationsController < BaseController
            def index
              authorize! :read, SpreeVietqr::PaymentAllocation

              scope = store_scope
              scope = scope.where(payment_method: find_payment_method!(params[:payment_method_id])) if params[:payment_method_id].present?
              scope = scope.where(status: params[:status]) if params[:status].present?
              scope = scope.where(order_number: params[:order_number].to_s.strip.upcase) if params[:order_number].present?
              render_page(scope.includes(:order, :payment, :payment_method, :receiving_account).ordered_recently)
            end

            def show
              allocation = store_scope.find_by_prefix_id!(params[:id])
              authorize! :read, allocation

              render json: serialize(allocation)
            end

            private

            def store_scope
              SpreeVietqr::PaymentAllocation.where(payment_method_id: store_payment_methods.select(:id))
            end

            def serialize(allocation)
              serialize_allocation(allocation)
            end
          end
        end
      end
    end
  end
end
