require "test_helper"

class BugReportsControllerTest < ActionDispatch::IntegrationTest
  test "should get create" do
    get bug_reports_create_url
    assert_response :success
  end

  test "should get show" do
    get bug_reports_show_url
    assert_response :success
  end

  test "should get index" do
    get bug_reports_index_url
    assert_response :success
  end
end
