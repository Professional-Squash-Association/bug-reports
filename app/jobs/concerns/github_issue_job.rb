# Shared behavior for jobs that interact with GitHub issues.
# Provides record lookup, a configured Octokit client, and retry policy.
# Payload building lives in GithubIssuePayload so previews and dry runs
# render exactly what the jobs would send.
module GithubIssueJob
  extend ActiveSupport::Concern

  included do
    queue_as :default
    retry_on StandardError, wait: :polynomially_longer, attempts: 5
    # An issue deleted on GitHub is gone for good - retrying a sync against
    # it only produces five failures. (Declared after retry_on so it wins.)
    discard_on Octokit::NotFound
  end

  private

  def find_bug_report(id)
    BugReport.find(id)
  end

  def github_client
    GithubApp.client
  end
end
