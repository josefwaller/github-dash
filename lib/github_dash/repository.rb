require "octokit"
require 'pp'

module GithubDash
  class Repository
    # Fetch a new repository
    def initialize(repo_name)
      # Use client if logged in
      @repo_data = client_for(repo_name).repository(repo_name)
    end

    # Get the raw octokit data
    def data
      @repo_data
    end

    # Update cached PR data
    def update_pull_requests(up_to=100)
      @pull_requests = client_for.pull_requests(@repo_data.full_name, :per_page => up_to)
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
      @commits = client_for.commits(@repo_data.full_name, :per_page => up_to)
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

    # Get a client which can access certain repository
    #   If passed without a pre_name parameter, assume that @repo_data has been
    #   initialized, and get the name from that
    def client_for(repo_name = nil)
      repo_name ||= @repo_data.full_name
      # Get the token
      token = GithubDash::DataDepository.get_token_for_repo(repo_name)
      # Use default client if the token is nil
      Octokit if token.nil?
      # Return new client
      client = Octokit::Client.new(:access_token => token)
    end
  end
end
