# frozen_string_literal: true

module Spree
  module Api
    module V3
      module Admin
        module Vietqr
          # Banks with a known VietQR BIN, for the receiving account form.
          class BanksController < BaseController
            def index
              authorize! :read, SpreeVietqr::ReceivingAccount

              banks = SpreeVietqr::PaymentInfo::BANK_NAMES.map { |bin, name| { bin: bin, name: name } }
              render json: { data: banks.sort_by { |bank| bank[:name] } }
            end
          end
        end
      end
    end
  end
end
