require "test_helper"

module BugReportsClient
  class BugReportsFlowTest < ActionDispatch::IntegrationTest
    API_ENDPOINT = "#{BugReportsClient::TestConfig::API_URL}/bug_reports".freeze

    setup do
      @user = create_user
    end

    test "requires authentication" do
      get "/bug_reports/new"

      assert_response :unauthorized
    end

    test "renders the schema-driven form" do
      # Avatar variant in the dummy layout mirrors host navbars (support et
      # al) - its URL must resolve via the host routes from engine pages.
      @user.avatar.attach(fixture_file_upload("screenshot.png", "image/png"))

      sign_in @user
      get "/bug_reports/new"

      assert_response :success
      assert_select "img[alt=avatar][src*='rails/active_storage/representations']"
      # Report type renders as radio cards, with bug selected by default.
      assert_select "input[type=radio][name='bug_report[report_type]'][value=bug][checked]"
      assert_select "input[type=radio][name='bug_report[report_type]'][value=feature]"
      # Shared fields plus a schema field from each type group.
      assert_select "input[name='bug_report[title]']"
      assert_select "select[name='bug_report[severity]']"
      assert_select "textarea[name='bug_report[responses][impact]']"
      assert_select "textarea[name='bug_report[responses][problem]']"
      assert_select "select[name='bug_report[responses][browser]']"
      # Screenshot dropzone: hidden file input driven by the Stimulus controller.
      assert_select "[data-controller='bug-reports-client--screenshot-dropzone']"
      assert_select "input[type=file][name='bug_report[screenshots][]'].hidden"
    end

    test "submits a bug, stores the remote id and builds the description from responses" do
      stub_request(:post, API_ENDPOINT).to_return(status: 202, body: { id: 55, status: "queued" }.to_json)

      sign_in @user
      post "/bug_reports", params: {
        bug_report: {
          title: "Filter is broken",
          report_type: "bug",
          severity: "high",
          responses: {
            impact: "Nobody can filter",
            expected_behaviour: "Filtering works",
            actual_behaviour: "Nothing happens",
            hacked_field: "should not be stored"
          }
        }
      }

      assert_redirected_to "/bug_reports/"
      report = BugReport.last
      assert_equal 55, report.remote_bug_report_id
      assert_equal "Nobody can filter", report.response(:impact)
      # Non-schema keys are filtered out by strong parameters.
      assert_nil report.response(:hacked_field)

      assert_requested(:post, API_ENDPOINT) do |request|
        body = JSON.parse(request.body)["bug_report"]
        body["description"].include?("Nobody can filter") &&
          body["reporter_email"] == @user.email &&
          body["reporter_name"] == @user.name
      end
    end

    test "switching type after filling submits only the selected type's fields" do
      stub_request(:post, API_ENDPOINT).to_return(status: 202, body: { id: 91 }.to_json)

      sign_in @user
      # A browser submit after switching bug -> feature: the bug group's
      # inputs are disabled by the report-type controller, so only feature
      # answers arrive.
      post "/bug_reports", params: {
        bug_report: {
          title: "Feature after switch", report_type: "feature",
          responses: { priority: "high", problem: "Too slow", solution: "Faster",
                       time_per_occurrence: "Daily", frequency: "Daily" }
        }
      }

      report = BugReport.last
      assert_nil report.response(:impact)
      assert_nil report.response(:expected_behaviour)

      assert_requested(:post, API_ENDPOINT) do |request|
        body = JSON.parse(request.body)["bug_report"]
        body["report_type"] == "feature" &&
          body["description"].include?("Too slow") &&
          !body["description"].include?("impact")
      end
    end

    test "even if both field sets are posted, the issue only contains the selected type's fields" do
      stub_request(:post, API_ENDPOINT).to_return(status: 202, body: { id: 92 }.to_json)

      sign_in @user
      # No-JS or tampered submit: both groups' answers arrive. The stored
      # responses may hold both, but the description (and so the GitHub
      # issue) is built strictly from the selected type's schema fields.
      post "/bug_reports", params: {
        bug_report: {
          title: "Both sets posted", report_type: "feature",
          responses: { priority: "low", problem: "A problem", solution: "A solution",
                       time_per_occurrence: "Daily", frequency: "Daily",
                       impact: "Bug impact text", expected_behaviour: "Bug expected text" }
        }
      }

      assert_requested(:post, API_ENDPOINT) do |request|
        description = JSON.parse(request.body)["bug_report"]["description"]
        description.include?("A problem") &&
          !description.include?("Bug impact text") &&
          !description.include?("Bug expected text")
      end
    end

    test "missing required schema fields re-render the form" do
      sign_in @user
      post "/bug_reports", params: {
        bug_report: { title: "Broken", report_type: "bug", severity: "low", responses: { impact: "" } }
      }

      assert_response :unprocessable_entity
      assert_equal 0, BugReport.count
    end

    test "a failed API call rolls the local record back and surfaces the error visibly" do
      stub_request(:post, API_ENDPOINT).to_return(status: 500, body: "boom")

      sign_in @user
      post "/bug_reports", params: {
        bug_report: {
          title: "Broken", report_type: "bug", severity: "low",
          responses: { impact: "x", expected_behaviour: "y", actual_behaviour: "z" }
        }
      }

      assert_response :unprocessable_entity
      assert_equal 0, BugReport.count
      # The failure renders in the self-scrolling error box, not a flash the
      # user might never see from the bottom of the form.
      assert_select "[data-controller='bug-reports-client--error-summary']",
                    text: /#{I18n.t("bug_reports_client.flashes.submit_failed")}/m
    end

    test "the submit button disables itself during submission" do
      sign_in @user
      get "/bug_reports/new"

      assert_select "input[type=submit][data-turbo-submits-with=?]", I18n.t("bug_reports_client.form.submitting")
    end

    test "hidden severity picker submits the default severity" do
      BugReportsClient.config.ask_severity = false
      stub_request(:post, API_ENDPOINT).to_return(status: 202, body: { id: 77 }.to_json)

      sign_in @user
      post "/bug_reports", params: {
        bug_report: {
          title: "Broken", report_type: "bug",
          responses: { impact: "x", expected_behaviour: "y", actual_behaviour: "z" }
        }
      }

      assert_equal "medium", BugReport.last.severity
    end

    test "screenshots attach on create, ignoring the file field's blank entry" do
      stub_request(:post, API_ENDPOINT).to_return(status: 202, body: { id: 88 }.to_json)

      sign_in @user
      post "/bug_reports", params: {
        bug_report: {
          title: "With screenshot", report_type: "bug", severity: "low",
          responses: { impact: "x", expected_behaviour: "y", actual_behaviour: "z" },
          # Multiple file inputs always submit a leading blank entry.
          screenshots: [ "", fixture_file_upload("screenshot.png", "image/png") ]
        }
      }

      report = BugReport.last
      assert_equal 1, report.screenshots.count
    end

    test "non-image files are rejected server-side even with a spoofed content type" do
      sign_in @user
      post "/bug_reports", params: {
        bug_report: {
          title: "Sneaky upload", report_type: "bug", severity: "low",
          responses: { impact: "x", expected_behaviour: "y", actual_behaviour: "z" },
          # A text file declared as image/png - Marcel sniffs the real bytes.
          screenshots: [ Rack::Test::UploadedFile.new(StringIO.new("#!/bin/sh\necho pwned"), "image/png", original_filename: "not-an-image.png") ]
        }
      }

      assert_response :unprocessable_entity
      assert_equal 0, BugReport.count
      assert_match I18n.t("bug_reports_client.errors.screenshot_type", filename: "not-an-image.png"), response.body
    end

    test "oversized screenshots are rejected" do
      BugReportsClient.config.max_screenshot_size = 10
      sign_in @user
      post "/bug_reports", params: {
        bug_report: {
          title: "Huge upload", report_type: "bug", severity: "low",
          responses: { impact: "x", expected_behaviour: "y", actual_behaviour: "z" },
          screenshots: [ fixture_file_upload("screenshot.png", "image/png") ]
        }
      }

      assert_response :unprocessable_entity
      assert_equal 0, BugReport.count
    end

    test "the update path cannot bypass the screenshot count limit" do
      report = create_bug_report(user: @user, remote_bug_report_id: 89)
      BugReportsClient.config.max_screenshots = 1

      sign_in @user
      patch "/bug_reports/#{report.id}", params: {
        bug_report: { title: "Over limit", report_type: "bug", severity: "low",
                      responses: { impact: "x" },
                      screenshots: [ fixture_file_upload("screenshot.png", "image/png"),
                                     fixture_file_upload("screenshot.png", "image/png") ] }
      }

      assert_response :unprocessable_entity
      assert_equal 0, report.reload.screenshots.count
      assert_equal "Something is broken", report.title
    end

    test "editing without new uploads keeps existing screenshots" do
      report = create_bug_report(user: @user, remote_bug_report_id: 88)
      report.screenshots.attach(fixture_file_upload("screenshot.png", "image/png"))
      stub_request(:patch, "#{API_ENDPOINT}/88").to_return(status: 200, body: { id: 88 }.to_json)

      sign_in @user

      # The edit form renders existing screenshot thumbnails via the HOST's
      # blob routes (engine routes can't resolve attachments).
      get "/bug_reports/#{report.id}/edit"
      assert_response :success
      assert_select "img[src*='rails/active_storage']"
      patch "/bug_reports/#{report.id}", params: {
        bug_report: { title: "Edited title", report_type: "bug", severity: "low",
                      responses: { impact: "still broken" },
                      screenshots: [ "" ] }
      }

      assert_equal "Edited title", report.reload.title
      assert_equal 1, report.screenshots.count
    end

    test "index lists only the current user's reports" do
      other_user = create_user(email: "other@example.test")
      mine = create_bug_report(user: @user, title: "My report")
      create_bug_report(user: other_user, title: "Someone else's report")

      sign_in @user
      get "/bug_reports"

      assert_response :success
      assert_match mine.title, response.body
      assert_no_match(/Someone else's report/, response.body)
    end

    test "editing another user's report is forbidden" do
      other_user = create_user(email: "other@example.test")
      report = create_bug_report(user: other_user)

      sign_in @user
      get "/bug_reports/#{report.id}/edit"

      assert_response :forbidden
    end

    test "updating an open report re-syncs the remote issue" do
      report = create_bug_report(user: @user, remote_bug_report_id: 55)
      stub = stub_request(:patch, "#{API_ENDPOINT}/55").to_return(status: 200, body: { id: 55 }.to_json)

      sign_in @user
      patch "/bug_reports/#{report.id}", params: {
        bug_report: { title: "Clearer title", report_type: "bug", severity: "high",
                      responses: { impact: "Updated impact" } }
      }

      assert_redirected_to "/bug_reports/#{report.id}/edit"
      assert_equal "Clearer title", report.reload.title
      assert_equal "Updated impact", report.response(:impact)
      assert_requested(stub)
    end

    test "the report type is locked after submission" do
      report = create_bug_report(user: @user, remote_bug_report_id: 90)
      stub_request(:patch, "#{API_ENDPOINT}/90").to_return(status: 200, body: { id: 90 }.to_json)

      sign_in @user

      # The edit form renders the cards disabled with an explanatory note.
      get "/bug_reports/#{report.id}/edit"
      assert_select "input[type=radio][name='bug_report[report_type]'][disabled]", count: 2
      assert_select "p", text: I18n.t("bug_reports_client.form.report_type.locked")

      # A tampered PATCH switching the type is ignored server-side.
      patch "/bug_reports/#{report.id}", params: {
        bug_report: { title: "Still a bug", report_type: "feature", severity: "medium",
                      responses: { impact: "unchanged" } }
      }

      assert_equal "bug", report.reload.report_type
      assert_equal "Still a bug", report.title
    end

    test "closed reports cannot be edited" do
      report = create_bug_report(user: @user, status: "closed")

      sign_in @user
      patch "/bug_reports/#{report.id}", params: { bug_report: { title: "Nope" } }

      assert_redirected_to "/bug_reports/#{report.id}/edit"
      assert_equal "Something is broken", report.reload.title
    end

    test "dismissing a resolved report sets dismissed_at via turbo stream" do
      report = create_bug_report(user: @user, status: "closed")

      sign_in @user
      patch "/bug_reports/#{report.id}", as: :turbo_stream

      assert_response :success
      assert report.reload.dismissed_at.present?
      assert_match "bug_report_#{report.id}", response.body
    end

    test "the all view is gated by admin_check" do
      sign_in @user
      get "/bug_reports/all"
      assert_redirected_to "/bug_reports/"

      admin = create_user(email: "admin@example.test", admin: true)
      other = create_user(email: "other@example.test")
      create_bug_report(user: other, title: "Someone else's report")

      sign_in admin
      get "/bug_reports/all"
      assert_response :success
      assert_match(/Someone else&#39;s report|Someone else's report/, response.body)
    end
  end
end
