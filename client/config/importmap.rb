# Pins the engine's Stimulus controllers into the host importmap. The
# controllers/ prefix means the host's standard Stimulus loading picks them up
# automatically with namespaced identifiers (bug-reports-client--*).
pin_all_from BugReportsClient::Engine.root.join("app/javascript/bug_reports_client/controllers"),
             under: "controllers/bug_reports_client",
             to: "bug_reports_client/controllers"
