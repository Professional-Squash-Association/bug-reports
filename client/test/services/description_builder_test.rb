require "test_helper"
require "tempfile"

module BugReportsClient
  class DescriptionBuilderTest < ActiveSupport::TestCase
    setup do
      @user = create_user(name: "Jane Reporter")
      @report = create_bug_report(user: @user, severity: "high",
        responses: {
          "impact" => "Everyone is affected",
          "expected_behaviour" => "It should work",
          "actual_behaviour" => "It does not work",
          "steps_to_reproduce" => "1. open page"
        })
    end

    test "default output includes severity line and answered fields in schema order" do
      output = DescriptionBuilder.new(@report).build

      assert_match(/\*\*Severity:\*\* high/, output)
      assert_match(/## #{Regexp.escape(I18n.t('bug_reports_client.fields.impact.label'))}\nEveryone is affected/, output)
      assert_match(/## #{Regexp.escape(I18n.t('bug_reports_client.fields.steps_to_reproduce.label'))}\n1\. open page/, output)
      # Answered fields keep schema order: impact before steps_to_reproduce.
      assert_operator output.index("Everyone is affected"), :<, output.index("1. open page")
    end

    test "default output skips unanswered fields" do
      output = DescriptionBuilder.new(@report).build

      assert_no_match(/#{Regexp.escape(I18n.t('bug_reports_client.fields.page_url.label'))}/, output)
    end

    test "feature reports use feature fields and no severity line" do
      feature = BugReport.create!(user: @user, title: "Idea", report_type: "feature",
        responses: { "priority" => "high", "problem" => "Too slow", "solution" => "Make it faster",
                     "time_per_occurrence" => "Daily", "frequency" => "Daily" })

      output = DescriptionBuilder.new(feature).build

      assert_no_match(/\*\*Severity/, output)
      assert_match(/## #{Regexp.escape(I18n.t('bug_reports_client.fields.problem.label'))}\nToo slow/, output)
    end

    test "a markdown template replaces placeholders" do
      Tempfile.create([ "issue", ".md" ]) do |file|
        file.write(<<~MD)
          **From:** {{reporter_name}} at {{app_name}}
          ## Impact
          {{impact}}
          Severity: {{severity}} / Type: {{report_type}} / Title: {{title}}
          Unknown: {{never_defined}}
        MD
        file.flush
        BugReportsClient.config.issue_template_path = file.path

        output = DescriptionBuilder.new(@report).build

        assert_match(/\*\*From:\*\* Jane Reporter at Dummy/, output)
        assert_match(/## Impact\nEveryone is affected/, output)
        assert_match(%r{Severity: high / Type: bug / Title: Something is broken}, output)
        # Unknown placeholders resolve to empty rather than leaking braces.
        assert_match(/Unknown: \n/, output)
      end
    end

    test "app_name config overrides the Rails application name" do
      BugReportsClient.config.app_name = "My Custom App"
      Tempfile.create([ "issue", ".md" ]) do |file|
        file.write("From {{app_name}}")
        file.flush
        BugReportsClient.config.issue_template_path = file.path

        assert_equal "From My Custom App", DescriptionBuilder.new(@report).build
      end
    end
  end
end
