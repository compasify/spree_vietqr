# frozen_string_literal: true

module Spree
  module Admin
    class WebhookEventsController < Spree::Admin::BaseController
      include Spree::Admin::TableConcern
      include Pagy::Method

      use_table :vietqr_webhook_events

      def index
        @search = SpreeVietqr::WebhookEvent.ransack(params[:q])
        @search.sorts = 'created_at desc' if @search.sorts.empty?

        process_table_query_state if table_registered?

        result = @search.result(distinct: true)
        @pagy, @collection = pagy(result, limit: 50)

        @stats = {
          total_today: SpreeVietqr::WebhookEvent.where('created_at > ?', Time.current.beginning_of_day).count,
          confirmed_today: SpreeVietqr::WebhookEvent.where(status: 'confirmed').where('created_at > ?', Time.current.beginning_of_day).count,
          unmatched: SpreeVietqr::WebhookEvent.unmatched.count
        }
      end

      def show
        @event = SpreeVietqr::WebhookEvent.find(params[:id])
      end

      def manual_match
        @event = SpreeVietqr::WebhookEvent.find(params[:id])
        order = Spree::Order.find_by(number: params[:order_number])

        unless order
          flash[:error] = "Order #{params[:order_number]} not found"
          return redirect_to admin_webhook_event_path(@event)
        end

        if @event.amount_cents.present? && order.total.to_i != @event.amount_cents.to_i
          flash[:error] = "Amount mismatch: webhook #{@event.amount_cents}, order #{order.total.to_i}"
          return redirect_to admin_webhook_event_path(@event)
        end

        allocation = match_allocation_for_manual(order)
        unless allocation
          flash[:error] = 'No matching allocation found for this webhook/order/account'
          return redirect_to admin_webhook_event_path(@event)
        end

        if confirmer.call(allocation: allocation, webhook_event: @event)
          flash[:success] = "Payment confirmed for #{order.number}"
        else
          flash[:error] = 'Failed to confirm payment'
        end

        redirect_to admin_webhook_event_path(@event)
      end

      def retry_processing
        @event = SpreeVietqr::WebhookEvent.find(params[:id])
        provider = SpreeVietqr::Providers::Registry.resolve(@event.provider).new(payment_method: payment_method, receiving_account: @event.receiving_account)
        transaction = provider.parse_transaction(@event.raw_payload)
        allocation = SpreeVietqr::MatchTransaction.new(payment_method: payment_method, receiving_account: @event.receiving_account).call(transaction)

        if allocation && confirmer.call(allocation: allocation, webhook_event: @event)
          flash[:success] = "Re-processed: payment confirmed for #{allocation.order_number}"
        else
          @event.mark_status!('unmatched') unless allocation
          flash[:warning] = 'Re-processed: no matching payable order found'
        end

        redirect_to admin_webhook_event_path(@event)
      rescue StandardError => e
        @event.mark_status!('error', error: e.message)
        flash[:error] = "Retry failed: #{e.message}"
        redirect_to admin_webhook_event_path(@event)
      end

      private

      def payment_method
        @payment_method ||= @event.payment_allocation&.payment_method ||
                            @event.payment_method ||
                            @event.receiving_account&.payment_method ||
                            Spree::PaymentMethod::Vietqr.active.detect { |method| method.receiving_accounts.active.for_provider(@event.provider).exists? } ||
                            Spree::PaymentMethod::Vietqr.active.first
      end

      def confirmer
        SpreeVietqr::ConfirmPayment.new(payment_method: payment_method)
      end

      def match_allocation_for_manual(order)
        scope = SpreeVietqr::PaymentAllocation.active
          .where(order: order, payment_method: payment_method)
          .where(expected_amount: @event.amount_cents.to_i)

        scope.find do |allocation|
          event_account_matches?(allocation)
        end
      end

      def event_account_matches?(allocation)
        return false if @event.account_number.blank? && @event.virtual_account_number.blank? && @event.payment_link_id.blank?
        return true if @event.payment_link_id.present? && allocation.payment_link_id == @event.payment_link_id
        return true if @event.receiving_account_id.present? && allocation.receiving_account_id == @event.receiving_account_id

        account_matches = @event.account_number.present? && SpreeVietqr::AccountIdentifier.account_number_matches?(allocation.account_number, @event.account_number)
        bank_matches = @event.bank_bin.blank? || SpreeVietqr::AccountIdentifier.normalize_number(@event.bank_bin).blank? || SpreeVietqr::AccountIdentifier.normalize_number(allocation.bank_bin) == SpreeVietqr::AccountIdentifier.normalize_number(@event.bank_bin)
        sub_account_matches = allocation.sub_account.blank? || (@event.sub_account.present? && allocation.sub_account == SpreeVietqr::AccountIdentifier.normalize_text(@event.sub_account))
        virtual_account_matches = allocation.virtual_account_number.blank? || (@event.virtual_account_number.present? && SpreeVietqr::AccountIdentifier.normalize_number(allocation.virtual_account_number) == SpreeVietqr::AccountIdentifier.normalize_number(@event.virtual_account_number))

        account_matches && bank_matches && sub_account_matches && virtual_account_matches
      end
    end
  end
end
