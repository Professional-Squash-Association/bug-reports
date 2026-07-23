require "test_helper"

module BugReportsClient
  class BugReportTest < ActiveSupport::TestCase
    setup do
      @user = create_user
    end

    test "valid bug with required responses saves" do
      report = create_bug_report(user: @user)

      assert report.persisted?
      assert_equal "open", report.status
    end

    test "requires title and report type" do
      report = BugReport.new(user: @user)

      assert_not report.valid?
      assert report.errors[:title].present?
    end

    test "bugs require a severity" do
      report = BugReport.new(user: @user, title: "Broken", report_type: "bug",
                             responses: { "impact" => "x", "expected_behaviour" => "y", "actual_behaviour" => "z" })

      assert_not report.valid?
      assert report.errors[:severity].present?
    end

    test "schema-required responses are enforced with field labels" do
      report = BugReport.new(user: @user, title: "Broken", report_type: "bug", severity: "low")

      assert_not report.valid?
      assert report.errors[:base].any? { |message| message.include?(I18n.t("bug_reports_client.fields.impact.label")) }
    end

    test "features enforce their own required fields" do
      report = BugReport.new(user: @user, title: "Idea", report_type: "feature")

      assert_not report.valid?
      assert report.errors[:base].any? { |message| message.include?(I18n.t("bug_reports_client.fields.problem.label")) }
    end

    test "responses merge instead of replace" do
      report = create_bug_report(user: @user)
      report.responses = { "steps_to_reproduce" => "1. do the thing" }

      assert_equal "Everyone is affected", report.response(:impact)
      assert_equal "1. do the thing", report.response(:steps_to_reproduce)
    end

    test "importance is severity for bugs and the priority response for features" do
      bug = create_bug_report(user: @user, severity: "high")
      feature = BugReport.new(report_type: "feature", responses: { "priority" => "low" })

      assert_equal "high", bug.importance
      assert_equal "low", feature.importance
    end

    test "type_noun is localised" do
      assert_equal "bug report", BugReport.new(report_type: "bug").type_noun
      assert_equal "feature request", BugReport.new(report_type: "feature").type_noun
    end

    test "resolved_and_undismissed scope" do
      open_report = create_bug_report(user: @user)
      resolved = create_bug_report(user: @user, status: "closed")
      dismissed = create_bug_report(user: @user, status: "closed", dismissed_at: Time.current)

      results = BugReport.resolved_and_undismissed
      assert_includes results, resolved
      assert_not_includes results, open_report
      assert_not_includes results, dismissed
    end

    test "remote id must be unique" do
      create_bug_report(user: @user, remote_bug_report_id: 42)
      duplicate = BugReport.new(user: @user, title: "Another", report_type: "bug", severity: "low",
                                remote_bug_report_id: 42,
                                responses: { "impact" => "x", "expected_behaviour" => "y", "actual_behaviour" => "z" })

      assert_not duplicate.valid?
    end
  end
end
