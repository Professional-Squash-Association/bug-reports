require_relative "lib/bug_reports_client/version"

Gem::Specification.new do |spec|
  spec.name        = "bug_reports_client"
  spec.version     = BugReportsClient::VERSION
  spec.authors     = [ "PSA Squash Tour" ]
  spec.email       = [ "harry.mattocks@psasquashtour.com" ]
  spec.homepage    = "https://github.com/Professional-Squash-Association/bug-reports"
  spec.summary     = "Mountable Rails engine for submitting bug reports and feature requests to a central bug-reports API"
  spec.description = "Adds a fully-featured, customisable bug and feature reporting flow to any Rails app: " \
                     "a schema-driven form, screenshot uploads, a my-reports list, and signed closure " \
                     "webhooks from the companion bug-reports API which files GitHub issues."
  spec.license     = "MIT"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = spec.homepage
  spec.metadata["changelog_uri"] = "#{spec.homepage}/blob/main/client/CHANGELOG.md"
  spec.metadata["rubygems_mfa_required"] = "true"

  spec.files = Dir.chdir(File.expand_path(__dir__)) do
    Dir["{app,config,db,lib}/**/*", "MIT-LICENSE", "README.md", "CHANGELOG.md"]
      .reject { |path| File.basename(path).start_with?(".") }
  end

  spec.required_ruby_version = ">= 3.2"

  spec.add_dependency "rails", ">= 8.0"
  spec.add_dependency "turbo-rails", ">= 2.0"
end
