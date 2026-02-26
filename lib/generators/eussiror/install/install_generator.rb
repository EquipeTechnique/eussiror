# frozen_string_literal: true

require "rails/generators"

module Eussiror
  module Generators
    class InstallGenerator < Rails::Generators::Base
      source_root File.expand_path("templates", __dir__)

      desc "Creates an Eussiror initializer in config/initializers."

      def create_initializer_file
        template "initializer.rb.tt", "config/initializers/eussiror.rb"
      end
    end
  end
end
