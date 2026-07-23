class User < ApplicationRecord
  include BugReportsClient::Reporter

  # Mirrors host apps whose navbars render an avatar variant on every page.
  has_one_attached :avatar
end
