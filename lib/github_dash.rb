require "github_dash/version"
require "github_dash/repository"
require "github_dash/data_depository"
require "octokit"

module GithubDash
  # Fetch repository information given a reposoitory name
  def self.fetch_repository(repository_name)
    Repository.new repository_name
  end

  # Add a repository to the list of followed repositories
  def self.add_repo_to_following(name)
    # Make sure the repository exists in github
    Repository.new(name)
    DataDepository.add_repo name, DataDepository.get_token
  end

  # Remove a repository from the list of followed repositories
  def self.remove_repo_from_following(name)
    # Tell the user whether it removed a repo or not
    DataDepository.remove_repo name
  end

  # Get an array of the names of followed repositories
  def self.get_following
    DataDepository.get_following
  end

  # Save a user's token for getting private repositories
  def self.add_user(username, password)
    # Create new token
    client = Octokit::Client.new :login => username, :password => password
    token = client.create_authorization(:scopes => ["repo"], :note => "github-dash token").token

    # Save it
    DataDepository.save_token(token)
  end

  # Add a token and set it to be used first when fetching repositories
  def self.add_token(token)
    DataDepository.save_token(token)
  end

  # Get either an Octokit::Client if a token has been saved,
  #   or nil if one hasn't.
  def self.get_client
    # Return nil if no token has been saved
    nil if DataDepository.get_token.nil?
    # Return new client
    Octokit::Client.new(:access_token => DataDepository.get_token)
  end
end
