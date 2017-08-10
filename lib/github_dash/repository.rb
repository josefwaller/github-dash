require "octokit"
require 'pp'

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

    # Get the pull requests opened in the last so many days
    def get_pull_requests(days=7, up_to=100)
      Octokit.pull_requests(@repo_data.full_name, :per_page => up_to).take_while do |pr|
        pr.created_at.to_date > Date.today - days
      end
    end
  end
end
