require "github_dash"
require "sequel"

module GithubDash

  # Store and manage all repositories the user choses to follow
  #   and the tokens needed to access them
  class DataDepository

    # Save a repo name in the following list
    def self.add_repo(repo_name)
      # Check the repo is not already followed
      if get_db[:repos].where(:name => repo_name.downcase).all.count > 0
        raise ArgumentError, "Tried to follow a repository that was already followed!"
      end

      # Add repository to database
      get_db[:repos].insert(:name => repo_name.downcase)
    end

    # Remove a repository from a list of followed repositories
    def self.remove_repo(repo_name)
      # Remove the repository
      if get_db[:repos].where(:name => repo_name.downcase).delete == 0
        # `delete` will return the number of entries deleted
        #   So if none were deleted, raise an error
        raise ArgumentError, "Tried removing a repository that was not followed!"
      end
    end

    # Get an array of the names of followed repositories
    def self.get_following
      # Create an arrau of just the repo's names
      get_db[:repos].all.map do |r|
        r[:name]
      end
    end

    # Save a token to be used for logging in
    def self.save_token(token)
      # Remove any previous tokens
      get_db[:tokens].delete

      # Add this token
      get_db[:tokens].insert(:token => token)
    end

    # Get the github API token
    def self.get_token
      # Will return nil if empty
      return nil if get_db[:tokens].first.nil?

      # Return the actual token
      get_db[:tokens].first[:token]
    end

    # Get the database from the .db file and creates
    #   all tables unless they already exist
    def self.get_db

      # Does not load the database twice
      unless class_variable_defined?(:@@db)

        @@db = Sequel.sqlite("#{ENV['HOME']}/.github_dash/data.db")

        # Create the tables
        #   Note: create_table? works the same as create_table,
        #   except that it will not override an existing table
        #   with the same name.
        @@db.create_table? :repos do
          primary_key :id
          String :name
        end

        @@db.create_table? :tokens do
          primary_key :id
          String :token
        end
      end

      @@db
    end

    private_class_method :get_db
  end
end
