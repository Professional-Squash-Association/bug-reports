# Loads the source-to-GitHub-repository mapping from config/repo_mapping.yml.
# Used by BugReport#resolved_repo and the GitHub issue creation job.
class RepoMapping
  MAPPING = YAML.safe_load_file(Rails.root.join("config/repo_mapping.yml"), permitted_classes: []).freeze

  def self.repo_for(source)
    MAPPING[source]
  end

  def self.valid_source?(source)
    MAPPING.key?(source)
  end

  def self.all_sources
    MAPPING.keys
  end
end
