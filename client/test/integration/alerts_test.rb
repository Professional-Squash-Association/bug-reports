require "test_helper"

module BugReportsClient
  # Exercises the bug_report_alerts helper as a HOST layout uses it - the
  # dummy app's application layout renders it on every page.
  class AlertsTest < ActionDispatch::IntegrationTest
    setup do
      @user = create_user
    end

    test "resolved reports show a dismissable alert on host pages" do
      report = create_bug_report(user: @user, status: "closed")

      sign_in @user
      get "/"

      assert_response :success
      assert_select "#bug_report_alerts"
      assert_select "#bug_report_#{report.id}" do
        assert_select "form[action=?]", "/bug_reports/#{report.id}"
      end
      assert_match report.title, response.body
    end

    test "no alerts render when nothing is resolved" do
      create_bug_report(user: @user)

      sign_in @user
      get "/"

      assert_select "#bug_report_alerts", count: 0
    end

    test "dismissed reports no longer alert" do
      create_bug_report(user: @user, status: "closed", dismissed_at: Time.current)

      sign_in @user
      get "/"

      assert_select "#bug_report_alerts", count: 0
    end

    test "signed-out visitors see no alerts and no errors" do
      get "/"

      assert_select "#bug_report_alerts", count: 0
    end
  end
end
