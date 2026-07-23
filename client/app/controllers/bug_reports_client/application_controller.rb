module BugReportsClient
  # Inherits from the host app's ApplicationController (configurable) so the
  # engine's pages get the host layout, session handling and flash styling for
  # free. Authentication is enforced through the configured method name, which
  # covers both Devise hosts and bespoke session auth.
  class ApplicationController < BugReportsClient.config.parent_controller.constantize
    # Host layouts reference host route helpers; delegate the ones the engine
    # doesn't define to the host app so layouts render unmodified.
    helper BugReportsClient::MainAppRoutes

    # Only enforce our own authentication when the host asks us to. Hosts that
    # already authenticate globally (a `before_action :authenticate_user!` in
    # their ApplicationController, which we inherit) set
    # config.authenticate_method = nil to avoid running auth twice per request.
    before_action :authenticate_reporter!, if: -> { BugReportsClient.config.authenticate_method.present? }

    helper_method :bug_reports_current_user, :bug_reports_admin?

    private

    def authenticate_reporter!
      send(BugReportsClient.config.authenticate_method)
    end

    # The signed-in user, via the host's configured accessor.
    def bug_reports_current_user
      send(BugReportsClient.config.current_user_method)
    end

    def bug_reports_admin?
      user = bug_reports_current_user
      user.present? && BugReportsClient.config.admin?(user)
    end
  end
end
