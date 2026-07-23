# Engine routes. Hosts mount the engine (usually at /bug_reports), giving:
#   GET  /bug_reports          - my reports
#   GET  /bug_reports/new      - the report form
#   GET  /bug_reports/all      - every report (admins, via config.admin_check)
#   POST /bug_reports/webhook  - signed closure callbacks from the API
BugReportsClient::Engine.routes.draw do
  resources :bug_reports, path: "", only: %i[index new create edit update] do
    collection do
      get :all
    end
  end

  post "webhook", to: "webhooks#receive"
end
