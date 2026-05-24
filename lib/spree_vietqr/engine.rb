# frozen_string_literal: true

module SpreeVietqr
  class Engine < ::Rails::Engine
    require 'spree/core'
    require File.expand_path('../../app/middleware/spree_vietqr/raw_body_middleware', __dir__)
    isolate_namespace SpreeVietqr

    engine_name 'spree_vietqr'

    initializer 'spree_vietqr.assets' do |app|
      app.config.assets.precompile += %w[spree_vietqr/application.css spree_vietqr/application.js] if app.config.respond_to?(:assets)
    end

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

    initializer 'spree_vietqr.providers' do
      require_dependency 'spree_vietqr/providers/base'
      require_dependency 'spree_vietqr/providers/registry'
      require_dependency 'spree_vietqr/providers/sepay'
      require_dependency 'spree_vietqr/providers/payos'

      SpreeVietqr::Providers::Registry.register('sepay', SpreeVietqr::Providers::Sepay)
      SpreeVietqr::Providers::Registry.register('payos', SpreeVietqr::Providers::Payos)
    end

    initializer 'spree_vietqr.mount_routes' do |app|
      app.routes.append do
        mount SpreeVietqr::Engine, at: '/'
      end
    end

    initializer 'spree_vietqr.admin_menu' do
      next unless defined?(Spree::Backend::Config)

      Spree::Backend::Config.configure do |config|
        next unless config.respond_to?(:menu_items) && config.class.const_defined?(:MenuItem)

        config.menu_items << config.class::MenuItem.new(
          label: :vietqr_accounts,
          icon: 'ri-qr-code-line',
          url: '/admin/vietqr_payment_methods',
          condition: -> { can?(:admin, Spree::PaymentMethod) }
        )

        config.menu_items << config.class::MenuItem.new(
          label: :webhook_events,
          icon: 'ri-webhook-line',
          url: '/admin/webhook_events',
          condition: -> { can?(:admin, SpreeVietqr::WebhookEvent) }
        )
      end
    end

    def self.activate
      Dir.glob(File.join(File.dirname(__FILE__), '../../app/**/*_decorator*.rb')).sort.each do |c|
        Rails.configuration.cache_classes ? require(c) : load(c)
      end
    end

    config.to_prepare(&method(:activate).to_proc)
  end
end
