require "github_dash"

module GithubDash

  # Store and manage all repositories the user choses to follow
  #   and the tokens needed to access them
  class DataDepository

    # Save a repo name in the following list
    def self.add_repo(repo_name)
      create_settings_dir

      # Open it
      File.open repos_file_path, 'a+' do |f|
        # Read all contents and make sure the file doesn't already
        #   contain this repository
        contents = f.read
        contents.gsub(/\r\n?/, "\n")
        contents.each_line do |l|
          if l.gsub(/\n/, "") == repo_name
            raise ArgumentError, "Tried to follow a repository that was already followed"
          end
        end

        # Add repository to file
        f.puts repo_name
      end
    end

    # Remove a repository from a list of followed repositories
    def self.remove_repo(repo_name)
      create_settings_dir

      # Load the currently followed repos
      contents = File.read repos_file_path

      # Go through each repo and remove the designated repo
      contents = contents.gsub(/\r\n/, "\n").split("\n").reject! do |line|
        line.downcase == repo_name.downcase
      end

      # reject! will return nil if it did not change the array
      if contents.nil?
        raise ArgumentError, "Tried removing a repository that was already followed!"
      end

      # Save new following
      File.write repos_file_path, contents.join("\n")

    end

    # Get an array of the names of followed repositories
    def self.get_following
      # Read the repos file
      file = File.read repos_file_path

      # Split the contents by a linebreak and return
      file.split("\n")
    end

    # Save a token to be used for logging in
    def self.save_token(token)
      # Save token
      File.write "#{ENV['HOME']}/.github_dash/token.txt", token
    end

    # Get the github API token
    def self.get_token
      begin
        # Return the contents of the token file
        File.read "#{ENV['HOME']}/.github_dash/token.txt"
      rescue Errno::ENOENT
        # Return nil if the file doesn't exist
        nil
      end
    end

    # Get the path to the file containing all followed repos' names
    def self.repos_file_path
      "#{ENV['HOME']}/.github_dash/repositories.txt"
    end

    # Create the settings directory, where all data files are kept
    def self.create_settings_dir
      # Get the directory name
      dirname = File.dirname repos_file_path

      # Create it and parent folders if they don't exist
      unless File.directory? dirname
        FileUtils.mkdir_p dirname
      end

      # Create an empty file if the file does not exist
      unless File.file? repos_file_path
        File.open(repos_file_path, "w").close
      end
    end

    private_class_method :create_settings_dir, :repos_file_path
  end
end
