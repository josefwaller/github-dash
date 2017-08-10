require "octokit"

module GithubDash
  class Repository
    # Fetch a new repository
    def initialize(repository_url)
      @repo_data = Octokit.repository(repository_url)
    end

    # Get the raw octokit data
    def data
      @repo_data
    end
  end
end
