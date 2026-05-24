# frozen_string_literal: true

module Spree
  module Admin
    class VietqrPaymentMethodsController < Spree::Admin::BaseController
      def index
        @payment_methods = Spree::PaymentMethod::Vietqr
          .includes(:receiving_accounts)
          .order(:name, :id)
      end
    end
  end
end
