# frozen_string_literal: true

module SpreeVietqr
  class Engine < ::Rails::Engine
    require 'spree/core'
    isolate_namespace Spree

    engine_name 'spree_vietqr'

    initializer 'spree_vietqr.assets' do |app|
      app.config.assets.precompile += %w[spree_vietqr/application.css spree_vietqr/application.js] if app.config.respond_to?(:assets)
    end

    def self.activate
      Dir.glob(File.join(File.dirname(__FILE__), '../../app/**/*_decorator*.rb')).sort.each do |c|
        Rails.configuration.cache_classes ? require(c) : load(c)
      end
    end

    config.to_prepare(&method(:activate).to_proc)
  end
end
