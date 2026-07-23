require "test_helper"
require "rails/generators"
require "rails/generators/test_case"
require "generators/bug_reports_client/views/views_generator"

module BugReportsClient
  class ViewsGeneratorTest < Rails::Generators::TestCase
    tests Generators::ViewsGenerator
    destination File.expand_path("../tmp/views_generator", __dir__)

    setup :prepare_destination

    test "copies the engine views for host customisation" do
      run_generator

      assert_file "app/views/bug_reports_client/bug_reports/_form.html.erb"
      assert_file "app/views/bug_reports_client/bug_reports/_field_text.html.erb"
      assert_file "app/views/bug_reports_client/bug_reports/index.html.erb"
      assert_file "app/views/bug_reports_client/shared/_alerts.html.erb"
    end
  end
end
