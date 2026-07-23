require "test_helper"
require "rails/generators"
require "rails/generators/test_case"
require "generators/bug_reports_client/install/install_generator"

module BugReportsClient
  class InstallGeneratorTest < Rails::Generators::TestCase
    tests Generators::InstallGenerator
    destination File.expand_path("../tmp/install_generator", __dir__)

    setup :prepare_destination
    setup do
      # The route injector needs an existing routes file to modify.
      FileUtils.mkdir_p(File.join(destination_root, "config"))
      File.write(File.join(destination_root, "config/routes.rb"), "Rails.application.routes.draw do\nend\n")
    end

    test "creates the initializer with the app-derived source" do
      run_generator

      assert_file "config/initializers/bug_reports_client.rb", /config\.source = "dummy"/
    end

    test "mounts the engine" do
      run_generator

      assert_file "config/routes.rb", /mount BugReportsClient::Engine => "\/bug_reports"/
    end

    test "copies the default form schema and issue template example" do
      run_generator

      assert_file "config/bug_report_form.yml", /field: impact/
      assert_file "config/bug_report_issue.md.example", /\{\{severity\}\}/
    end
  end
end
