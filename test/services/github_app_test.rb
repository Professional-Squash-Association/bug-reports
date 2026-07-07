require "test_helper"

class GithubAppTest < ActiveSupport::TestCase
  test "uses the personal access token when the app is not configured" do
    with_env("GITHUB_APP_ID" => nil, "GITHUB_TOKEN" => "pat-123") do
      client = GithubApp.client

      assert_instance_of Octokit::Client, client
      assert_equal "pat-123", client.access_token
    end
  end

  test "builds an app-authenticated client when configured" do
    key = OpenSSL::PKey::RSA.new(2048).to_pem

    with_env("GITHUB_APP_ID" => "12345", "GITHUB_APP_INSTALLATION_ID" => "67890", "GITHUB_APP_PRIVATE_KEY" => key) do
      github_app = GithubApp.new
      # Stub the installation-token exchange so we don't hit GitHub.
      github_app.define_singleton_method(:installation_token) { "ghs_installation" }

      client = github_app.client
      assert_equal "ghs_installation", client.access_token
    end
  end

  private

  def with_env(vars)
    original = vars.keys.index_with { |k| ENV[k] }
    vars.each { |k, v| v.nil? ? ENV.delete(k) : ENV[k] = v }
    yield
  ensure
    original.each { |k, v| v.nil? ? ENV.delete(k) : ENV[k] = v }
  end
end
