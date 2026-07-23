# Moves the source-to-repository mapping from config/repo_mapping.yml onto
# the ApiKey record itself, so onboarding an app is a single database record
# (no config edit + deploy). The historical YAML mapping is embedded below to
# backfill existing keys; new keys set github_repo at creation.
class AddGithubRepoToApiKeys < ActiveRecord::Migration[8.1]
  # The mapping as it stood in config/repo_mapping.yml when it was retired.
  LEGACY_MAPPING = {
    "secure" => "Professional-Squash-Association/secure",
    "dashboard" => "Professional-Squash-Association/dashboard",
    "invoices" => "Professional-Squash-Association/invoices",
    "support" => "Professional-Squash-Association/support",
    "refhub" => "Professional-Squash-Association/refhub",
    "racketref" => "Professional-Squash-Association/racketref",
    "fantasy" => "Professional-Squash-Association/fantasy"
  }.freeze

  def up
    add_column :api_keys, :github_repo, :string

    LEGACY_MAPPING.each do |source, repo|
      execute <<~SQL.squish
        UPDATE api_keys SET github_repo = #{quote(repo)} WHERE name = #{quote(source)}
      SQL
    end
  end

  def down
    remove_column :api_keys, :github_repo
  end

  private

  def quote(value)
    ActiveRecord::Base.connection.quote(value)
  end
end
