class ApplicationController < ActionController::API
  private

  # Authenticates requests using a bearer token from the Authorization header.
  # Each consuming app holds its own token generated via ApiKey.create!.
  def authenticate_api_key
    token = request.headers["Authorization"]&.delete_prefix("Bearer ")
    @current_api_key = ApiKey.find_by(token: token) if token.present?
    unless @current_api_key
      render json: { error: "Unauthorised" }, status: :unauthorized
    end
  end

  def current_api_key
    @current_api_key
  end
end
