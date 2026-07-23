require "rails/generators"

module BugReportsClient
  module Generators
    # Copies the engine's views into the host app for full customisation:
    #   bin/rails g bug_reports_client:views
    #
    # Copied views shadow the engine's per-file (Rails checks the host first),
    # so you can copy everything and delete what you don't change. Note that
    # copied files no longer receive engine updates.
    class ViewsGenerator < Rails::Generators::Base
      source_root BugReportsClient::Engine.root.join("app/views").to_s

      def copy_views
        directory "bug_reports_client", "app/views/bug_reports_client"
      end
    end
  end
end
