module BugReportsClient
  # Included into ActionController::Base by the engine so every request tags
  # the Rails error-reporting context with the signed-in user's id. When an
  # unhandled 500 is captured, the reporter reads the id back and records an
  # ErrorEvent against that user - powering the "did your problem relate to
  # this error?" prompt on the bug report form. Deliberately silent on any
  # failure: attribution is best-effort and must never affect the request.
  module ErrorContext
    extend ActiveSupport::Concern

    included do
      before_action :set_bug_reports_error_context
    end

    private

    def set_bug_reports_error_context
      context = { bug_reports_controller: controller_name, bug_reports_action: action_name }

      method = BugReportsClient.config.current_user_method
      if respond_to?(method, true)
        user = send(method)
        context[:bug_reports_user_id] = user.id if user.respond_to?(:id) && user&.id
      end

      Rails.error.set_context(**context)
    rescue StandardError
      nil
    end
  end
end
