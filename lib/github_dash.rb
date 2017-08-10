require "github_dash/version"
require "github_dash/repository"
require "octokit"

module GithubDash
  # Fetch repository information given a reposoitory name
  def self.fetch_repository(repository_name)
    Repository.new repository_name
  end
end
