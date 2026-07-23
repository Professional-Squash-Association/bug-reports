Rails.application.routes.draw do
  mount BugReportsClient::Engine => "/bug_reports"

  root "home#index"

  # Host-only named route referenced by the dummy layout, mirroring real apps'
  # PWA manifest link (see MainAppRoutes delegation).
  get "manifest" => "home#index", as: :pwa_manifest

  # Test-only endpoints that raise, for exercising automatic error capture.
  get "boom", to: "home#boom"
  get "missing", to: "home#missing"

  # Test-only sign-in endpoint so integration tests can set the session user.
  post "test_session", to: "test_sessions#create"
end
