# frozen_string_literal: true

SpreeVietqr::Engine.routes.draw do
  scope 'webhooks/payments' do
    post ':provider', to: 'webhooks#receive', as: :payment_webhook
  end
end

Spree::Core::Engine.routes.draw do
  namespace :admin do
    resources :vietqr_payment_methods, only: :index

    resources :payment_methods, only: [] do
      resources :vietqr_receiving_accounts, except: :show
    end

    resources :webhook_events, only: %i[index show] do
      member do
        post :manual_match
        post :retry_processing
      end
    end
  end
end
