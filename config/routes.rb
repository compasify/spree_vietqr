# frozen_string_literal: true

SpreeVietqr::Engine.routes.draw do
  scope 'webhooks/payments' do
    post ':provider', to: 'webhooks#receive', as: :payment_webhook
  end
end

Spree::Core::Engine.add_routes do
  namespace :api, defaults: { format: 'json' } do
    namespace :v3 do
      namespace :store do
        # QR, bank details and status of an order paid by VietQR. `:id` is the
        # order's prefixed id or number; guests pass their order token.
        get 'orders/:id/vietqr', to: 'vietqr_payments#show', as: :order_vietqr_payment
      end

      namespace :admin do
        namespace :vietqr do
          get 'banks', to: 'banks#index'
          resources :receiving_accounts, only: %i[index show create update destroy]
          resources :payment_allocations, only: %i[index show]
          resources :webhook_events, only: %i[index show] do
            member do
              post :manual_match
              post :retry_processing
            end
          end
        end
      end
    end
  end
end
