Rails.application.routes.draw do
  namespace :api do
    resources :bug_reports, only: %i[create show index update]
    resources :webhooks, only: %i[create]
  end

  # Health check for load balancers and uptime monitors
  get "up" => "rails/health#show", as: :rails_health_check
end
