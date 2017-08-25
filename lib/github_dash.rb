require "github_dash/version"
require "github_dash/repository"
require "octokit"

module GithubDash
  # Fetch repository information given a reposoitory name
  def self.fetch_repository(repository_name, client=nil)
    Repository.new repository_name, client
  end
end
