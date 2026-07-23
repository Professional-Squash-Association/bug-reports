# Consuming apps are onboarded as ApiKey records, one per app:
#
#   ApiKey.create!(name: "myapp", github_repo: "my-org/myapp")
#
# The generated token (Bearer auth) and webhook_secret (callback signing) are
# what the app configures as BUG_REPORT_API_KEY and BUG_REPORT_WEBHOOK_SECRET.
#
# In development, a demo key is created so the API is usable out of the box.
if Rails.env.development? && ApiKey.none?
  demo = ApiKey.create!(name: "demo", github_repo: "example-org/demo-app")
  puts "Created demo API key:"
  puts "  source:         #{demo.name}"
  puts "  token:          #{demo.token}"
  puts "  webhook_secret: #{demo.webhook_secret}"
end
