# frozen_string_literal: true

module SpreeVietqr
  module Generators
    class InstallGenerator < Rails::Generators::Base
      class_option :migrate, type: :boolean, default: true

      def add_migrations
        run 'bundle exec rake railties:install:migrations FROM=spree_vietqr'
      end

      def run_migrations
        run_migrations = options[:migrate] || ['', 'y', 'Y'].include?(ask('Would you like to run the migrations now? [Y/n]'))
        if run_migrations
          run 'bundle exec rake db:migrate'
        else
          puts 'Skipping db:migrate, don\'t forget to run it!'
        end
      end
    end
  end
end
