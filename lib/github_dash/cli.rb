require "thor"
require "github_dash"
require "highline"
require "pp"
require "fileutils"

module GithubDash
  class CLI < Thor

    def initialize(*args)
      super
      @hl = HighLine.new
    end

    desc "add_repo REPO_NAME", "Adds a repository to the 'followed repositories' list"
    def add_repo(name)

      # Make sure the repository exists in github
      repo = GithubDash::fetch_repository(name)

      # Get the filepath to the followed repos file
      create_settings_dir

      # Open it
      File.open repos_file_path, 'a+' do |f|
        # Read all contents and make sure the file doesn't already
        #   contain this repository
        contents = f.read
        contents.gsub(/\r\n?/, "\n")
        contents.each_line do |l|
          if l.gsub(/\n/, "") == name
            # Warn user and quit
            @hl.say "Repository is already followed!"
            return
          end
        end
        # Add repopsitory to file
        f.puts (name)
        @hl.say "Added #{name} to followed repositories."
      end
    end

    desc "following", "Show all the repopsitories the user is following"
    def following

      create_settings_dir

      # Create an empty file if the file does not exist
      unless File.file? repos_file_path
        File.open(repos_file_path, "w").close
      end
      file = File.open(repos_file_path, "r")

      # Get the file contents
      contents = file.read
      file.close

      if contents.empty?
        @hl.say "Not following any repositories. Add repositories with add_repo."
      else
        # Log each repo
        contents.split("\n").each do |r|
          output = ""
          repo = GithubDash::fetch_repository r
          output += set_str_size(repo.data.full_name, 40)
          output += " | "
          output += "<%= color('#{set_str_size("#{repo.get_pull_requests.size} PRs in the last week", 40)}', GREEN) %>"
          output += " | "
          output += "<%= color('#{set_str_size("#{repo.get_commits.size} commits in the last week", 40)}', LIGHT_BLUE) %>"
          output += "\n"
          @hl.say output
        end
      end
    end

    option :days, :aliases => [:d], :type => :numeric, :default => 7
    desc "repo REPO_NAME", "Logs a bunch of information about a repository"
    def repo(name)
      repo = GithubDash::fetch_repository(name)
      @hl.say "=== #{repo.data.full_name} ==="
      @hl.say "=============================="
      @hl.say "Commits from the last #{options[:days]} day#{"s" if options[:days] > 1}."
      @hl.say "---------"
      repo.get_commits(days=options[:days]).each do |c|
        @hl.say "[#{c.commit.author.date}] - #{c.commit.message.split("\n").first} (by #{c.commit.author.name})"
        @hl.say "-----------------------"
      end
      @hl.say "=============================="
      @hl.say "PRs from the last #{options[:days]} day#{"s" if options[:days] > 1}."
      @hl.say "---------------"
      repo.get_pull_requests(days=options[:days]).each do |pr|
        @hl.say "[#{pr.updated_at}] - #{pr.title} (by #{pr.user.login})."
        @hl.say "-----------------------"
      end
    end

    no_commands do
      # Get the path to the file containing all followed repos' names
      def repos_file_path
        "#{ENV['HOME']}/.github_dash/repositories.txt"
      end

      # Minor helper method for setting string size
      #   will trunicate string if too big or add spaces if too small
      def set_str_size(str, size)
        str.ljust(size)[0..size]
      end

      def create_settings_dir
        dirname = File.dirname repos_file_path

        # Create it and parent folders if they don't exist
        unless File.directory? dirname
          FileUtils.mkdir_p dirname
        end
      end
      # Get the path to the file containing all followed repos' names
      def repos_file_path
        "#{ENV['HOME']}/.github_dash/repositories.txt"
      end

      def set_hl(hl)
        @hl = hl
      end
    end
  end
end
