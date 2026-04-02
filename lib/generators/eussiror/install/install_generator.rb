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

      def show_post_install_notice
        say <<~NOTICE, :green

          ================================================================================
          Eussiror has been installed.
          ================================================================================

          Next steps:
            1. Set GITHUB_TOKEN in your environment (never commit it to git).
            2. Set config.github_repository to your target repo (owner/repo).
            3. Adjust config.environments if needed (default: production only).
            4. Review config.issue_privacy — :minimal is safest for public GitHub repos;
               use :standard or :full only when issues are private to your team and you
               accept request / user context in issue bodies.

          See README.md for GitHub token setup, issue_privacy, and Rack env keys (eussiror.user_id).
        NOTICE
      end
    end
  end
end
