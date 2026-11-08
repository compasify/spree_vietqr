# frozen_string_literal: true

module SpreeVietqr
  module Generators
    # The engine loads its migrations from the gem itself, so installing only
    # needs the host database migrated.
    class InstallGenerator < Rails::Generators::Base
      class_option :migrate, type: :boolean, default: true

      def run_migrations
        if options[:migrate]
          run 'bin/rails db:migrate'
        else
          puts 'Skipping db:migrate, don\'t forget to run it!'
        end
      end
    end
  end
end
