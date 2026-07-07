require "test_helper"

class BugReportTest < ActiveSupport::TestCase
  def valid_attributes
    {
      title: "Something broke",
      description: "It doesn't work",
      severity: "medium",
      source: "secure",
      reporter_email: "test@example.com",
      reporter_name: "Test User",
      callback_url: "https://secure.example.com/api/bug_report_updates"
    }
  end

  test "valid with all required attributes" do
    assert BugReport.new(valid_attributes).valid?
  end

  %i[title description source callback_url].each do |field|
    test "invalid without #{field}" do
      report = BugReport.new(valid_attributes.except(field))
      assert_not report.valid?
      assert_includes report.errors[field], "can't be blank"
    end
  end

  test "invalid without reporter_email" do
    report = BugReport.new(valid_attributes.except(:reporter_email))
    assert_not report.valid?
  end

  test "invalid with badly formatted reporter_email" do
    report = BugReport.new(valid_attributes.merge(reporter_email: "not-an-email"))
    assert_not report.valid?
    assert_includes report.errors[:reporter_email], "is invalid"
  end

  test "invalid with unrecognised severity" do
    report = BugReport.new(valid_attributes.merge(severity: "extreme"))
    assert_not report.valid?
    assert_includes report.errors[:severity], "is not included in the list"
  end

  test "invalid with unrecognised source" do
    report = BugReport.new(valid_attributes.merge(source: "unknown_app"))
    assert_not report.valid?
    assert_includes report.errors[:source], "is not a recognised source"
  end

  test "resolved_repo returns mapped repository" do
    report = BugReport.new(valid_attributes)
    assert_equal RepoMapping.repo_for("secure"), report.resolved_repo
  end

  test "resolved_repo returns nil for unknown source" do
    report = BugReport.new(valid_attributes.merge(source: "nonexistent"))
    assert_nil report.resolved_repo
  end

  test "defaults status to pending" do
    report = BugReport.create!(valid_attributes)
    assert_equal "pending", report.status
  end

  test "defaults report_type to bug" do
    report = BugReport.create!(valid_attributes)
    assert_equal "bug", report.report_type
  end

  test "valid with feature report_type" do
    report = BugReport.new(valid_attributes.merge(report_type: "feature"))
    assert report.valid?
  end

  test "severity is required for bug reports" do
    report = BugReport.new(valid_attributes.merge(report_type: "bug", severity: nil))
    assert_not report.valid?
    assert_includes report.errors[:severity], "can't be blank"
  end

  test "severity is optional for feature requests" do
    report = BugReport.new(valid_attributes.merge(report_type: "feature", severity: nil))
    assert report.valid?
  end

  test "invalid with unrecognised report_type" do
    report = BugReport.new(valid_attributes.merge(report_type: "enhancement"))
    assert_not report.valid?
    assert_includes report.errors[:report_type], "is not included in the list"
  end

  test "defaults reporter_external to false" do
    report = BugReport.create!(valid_attributes)
    assert_not report.reporter_external?
  end
end
