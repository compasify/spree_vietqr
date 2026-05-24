# frozen_string_literal: true

module Spree
  module Admin
    class VietqrReceivingAccountsController < Spree::Admin::BaseController
      before_action :load_payment_method
      before_action :load_account, only: %i[edit update destroy]

      def index
        @accounts = @payment_method.receiving_accounts.ordered_for_routing
        @allocations = SpreeVietqr::PaymentAllocation
          .where(payment_method: @payment_method)
          .ordered_recently
          .limit(25)
      end

      def new
        @account = @payment_method.receiving_accounts.build(provider: 'manual')
      end

      def create
        @account = @payment_method.receiving_accounts.build(account_params)

        if @account.save
          flash[:success] = 'Đã thêm tài khoản'
          redirect_to admin_payment_method_vietqr_receiving_accounts_path(@payment_method)
        else
          render :new, status: :unprocessable_entity
        end
      end

      def edit; end

      def update
        if @account.update(account_params)
          flash[:success] = 'Đã lưu tài khoản'
          redirect_to admin_payment_method_vietqr_receiving_accounts_path(@payment_method)
        else
          render :edit, status: :unprocessable_entity
        end
      end

      def destroy
        if @account.payment_allocations.exists?
          @account.update!(active: false)
          flash[:success] = 'Tài khoản đã có giao dịch nên được tắt thay vì xóa'
        else
          @account.destroy!
          flash[:success] = 'Đã xóa tài khoản'
        end

        redirect_to admin_payment_method_vietqr_receiving_accounts_path(@payment_method)
      end

      private

      def load_payment_method
        @payment_method = Spree::PaymentMethod::Vietqr.find_by_prefix_id!(params[:payment_method_id])
      end

      def load_account
        @account = @payment_method.receiving_accounts.find(params[:id])
      end

      def account_params
        params.require(:receiving_account).permit(
          :bank_bin,
          :bank_name,
          :provider,
          :account_number,
          :account_name,
          :keyword_init,
          :sub_account,
          :virtual_account_number,
          :active,
          :priority,
          :routing_weight,
          :monthly_quota_amount,
          :monthly_threshold_amount,
          :webhook_secret,
          :payos_client_id,
          :payos_api_key,
          :payos_checksum_key
        )
      end
    end
  end
end
