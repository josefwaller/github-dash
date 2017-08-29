require "octokit"
require 'pp'

module GithubDash
  class Repository
    # Fetch a new repository
    def initialize(repository_url)
      begin
        # Use client if logged in
        client = GithubDash::get_client
        if client
          @repo_data = client.repository(repository_url)
        else
          @repo_data = Octokit.repository repository_url
        end
      rescue Octokit::NotFound
        raise ArgumentError, "Could not find #{repository_url}."
      end
    end

    # Get the raw octokit data
    def data
      @repo_data
    end

    # Update cached PR data
    def update_pull_requests(up_to=100)
      client = GithubDash::get_client
      client = Octokit if client.nil?
      @pull_requests = client.pull_requests(@repo_data.full_name, :per_page => up_to)
    end

    # Get the pull requests opened in the last so many days
    def get_pull_requests(days=7)
      update_pull_requests if @pull_requests.nil?
      @pull_requests.take_while do |pr|
        pr.created_at.to_date > Date.today - days
      end
    end

    # Update cached commits
    def update_commits(up_to=100)
      client = GithubDash::get_client
      client = Octokit if client.nil?
      @commits = client.commits(@repo_data.full_name, :per_page => up_to)
    end

    # Get all commits in a certain time period
    def get_commits(days=7, client=nil)
      update_commits if @commits.nil?
      # Note that while get_pull_requests can use take_while, commits will also include
      #   merges and therefore the dates are not neccissarily in order
      @commits.select do |c|
        c.commit.author.date.to_date > Date.today - days
      end
    end
  end
end
