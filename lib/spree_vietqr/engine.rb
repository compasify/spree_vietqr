# frozen_string_literal: true

module SpreeVietqr
  class Engine < ::Rails::Engine
    require 'spree/core'
    require 'spree/api'
    require File.expand_path('../../app/middleware/spree_vietqr/raw_body_middleware', __dir__)
    isolate_namespace SpreeVietqr

    engine_name 'spree_vietqr'

    initializer 'spree_vietqr.append_migrations' do |app|
      unless app.root.to_s.match?(root.to_s)
        config.paths['db/migrate'].expanded.each do |migration_path|
          app.config.paths['db/migrate'] << migration_path
        end
      end
    end

    initializer 'spree_vietqr.middleware' do |app|
      begin
        app.middleware.insert_before ActionDispatch::Static, SpreeVietqr::RawBodyMiddleware
      rescue RuntimeError
        app.middleware.use SpreeVietqr::RawBodyMiddleware
      end
    end

    # Admin API keys (read_vietqr / write_vietqr) and the CanCanCan subjects
    # they grant to staff roles.
    initializer 'spree_vietqr.permissions' do
      Spree.permissions.register_scope(:vietqr, group: :settings, resources: lambda {
        [SpreeVietqr::ReceivingAccount, SpreeVietqr::WebhookEvent, SpreeVietqr::PaymentAllocation]
      })
    end

    initializer 'spree_vietqr.mount_routes' do |app|
      app.routes.append do
        mount SpreeVietqr::Engine, at: '/'
      end
    end

    config.after_initialize do
      Spree.payment_methods << Spree::PaymentMethod::Vietqr unless Spree.payment_methods.include?(Spree::PaymentMethod::Vietqr)
    end

    config.to_prepare do
      SpreeVietqr::Providers::Registry.register('sepay', SpreeVietqr::Providers::Sepay)
      SpreeVietqr::Providers::Registry.register('payos', SpreeVietqr::Providers::Payos)
    end
  end
end
