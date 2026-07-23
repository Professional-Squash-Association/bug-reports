module BugReportsClient
  # Wires the engine into the host app: asset paths for Propshaft, importmap
  # pins for the Stimulus controllers, and helper exposure so host layouts can
  # call `bug_report_alerts` directly.
  class Engine < ::Rails::Engine
    isolate_namespace BugReportsClient

    config.generators do |g|
      g.test_framework :test_unit
    end

    # Serve the engine's JavaScript through the host's asset pipeline.
    initializer "bug_reports_client.assets" do |app|
      app.config.assets.paths << root.join("app/javascript") if app.config.respond_to?(:assets)
    end

    # Merge the engine's importmap pins into the host importmap. The pins live
    # under controllers/bug_reports_client/, which both eagerLoadControllersFrom
    # and lazyLoadControllersFrom scan, so the Stimulus controllers register as
    # bug-reports-client--report-type and bug-reports-client--file-limit with
    # no host JavaScript changes.
    initializer "bug_reports_client.importmap", before: "importmap" do |app|
      if app.config.respond_to?(:importmap)
        app.config.importmap.paths << root.join("config/importmap.rb")
        app.config.importmap.cache_sweepers << root.join("app/javascript")
      end
    end

    # Make engine helpers (bug_report_alerts and the badge helpers) available
    # in host views, so layouts can render the resolved-report alerts with a
    # single line.
    initializer "bug_reports_client.helpers" do
      ActiveSupport.on_load(:action_controller_base) do
        helper BugReportsClient::Engine.helpers
        # Tag requests with the current user so captured 500s can be
        # attributed to whoever hit them (see ErrorContext).
        include BugReportsClient::ErrorContext
      end
    end

    # Automatic 500 capture: subscribe to the Rails error reporter. The
    # subscription is unconditional (and cheap) - the reporter itself checks
    # config.error_reporting_enabled per report, so hosts can toggle the
    # flag without a restart and tests behave predictably.
    config.after_initialize do
      Rails.error.subscribe(BugReportsClient::ErrorReporter.new)
    end
  end
end
