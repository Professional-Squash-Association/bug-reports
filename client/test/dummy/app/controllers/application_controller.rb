# Stand-in for a host app's controller: session-based current_user and
# authenticate_user!, matching the engine's default config.
class ApplicationController < ActionController::Base
  helper_method :current_user

  def current_user
    @current_user ||= User.find_by(id: session[:user_id])
  end

  def authenticate_user!
    head :unauthorized unless current_user
  end
end
