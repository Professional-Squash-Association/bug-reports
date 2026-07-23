require "rails/generators"

module BugReportsClient
  module Generators
    # Sets a host app up to use the engine:
    #   bin/rails g bug_reports_client:install
    #
    # Creates the initializer, mounts the engine, copies the default form
    # schema (ready to customise) and an example issue template, then prints
    # the remaining manual checklist.
    class InstallGenerator < Rails::Generators::Base
      source_root File.expand_path("templates", __dir__)

      def create_initializer
        template "initializer.rb", "config/initializers/bug_reports_client.rb"
      end

      def mount_engine
        route 'mount BugReportsClient::Engine => "/bug_reports"'
      end

      # The copied schema is identical to the engine default - editing it (or
      # deleting it to fall back to the default) is the customisation point.
      def copy_form_schema
        copy_file BugReportsClient::Engine.root.join("config/form_schema.yml"), "config/bug_report_form.yml"
      end

      # Copied with an .example suffix because the presence of
      # config/bug_report_issue.md switches issue rendering to template mode.
      def copy_issue_template_example
        copy_file "bug_report_issue.md.example", "config/bug_report_issue.md.example"
      end

      def print_checklist
        readme "AFTER_INSTALL" if behavior == :invoke
      end
    end
  end
end
