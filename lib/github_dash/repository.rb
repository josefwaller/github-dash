require "octokit"
require 'pp'

module GithubDash
  class Repository
    # Fetch a new repository
    def initialize(repository_url)
      begin
        @repo_data = Octokit.repository(repository_url)
      rescue Octokit::NotFound
        raise ArgumentError, "Could not find #{repository_url}."
      end
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

    # Get all commits in a certain time period
    def get_commits(days=7, up_to=100)
      # Note that while get_pull_requests can use take_while, commits will also include
      #   merges and therefore the dates are not neccissarily in order
      Octokit.commits(@repo_data.full_name, :per_page => up_to).select do |c|
        c.commit.author.date.to_date > Date.today - days
      end
    end
  end
end
