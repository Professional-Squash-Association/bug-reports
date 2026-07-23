# Test-only: signs a user into the session for integration tests.
class TestSessionsController < ApplicationController
  def create
    session[:user_id] = params[:user_id]
    head :ok
  end
end
