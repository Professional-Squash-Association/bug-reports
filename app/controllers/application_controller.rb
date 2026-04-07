class ApplicationController < ActionController::API
  private

  # Authenticates requests using a bearer token from the Authorization header.
  # Each PSA app holds its own token generated via ApiKey.create!(name: "app-name").
  def authenticate_api_key
    token = request.headers["Authorization"]&.delete_prefix("Bearer ")
    unless token.present? && ApiKey.exists?(token: token)
      render json: { error: "Unauthorised" }, status: :unauthorized
    end
  end
end
