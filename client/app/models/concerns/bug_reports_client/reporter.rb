module BugReportsClient
  # Included into the host app's user model (one documented line) to link
  # users to their submitted reports:
  #
  #   class User < ApplicationRecord
  #     include BugReportsClient::Reporter
  #   end
  module Reporter
    extend ActiveSupport::Concern

    included do
      has_many :bug_reports, class_name: "BugReportsClient::BugReport", dependent: :destroy
    end
  end
end
