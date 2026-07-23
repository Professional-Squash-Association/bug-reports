# Developer tooling for inspecting bug reports without touching GitHub.
namespace :bug_reports do
  desc "Preview the GitHub issue payload for recent bug reports (LIMIT=10, ID=<id> for one)"
  task preview: :environment do
    reports =
      if ENV["ID"].present?
        [ BugReport.find(ENV["ID"]) ]
      else
        BugReport.order(created_at: :desc).limit(ENV.fetch("LIMIT", 10).to_i)
      end

    if reports.empty?
      puts "No bug reports found."
    else
      reports.each do |report|
        puts GithubDryRun.render("create", report)
        puts
      end
    end
  end
end
