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
      dirname = File.dirname(repos_file_path)

      # Create it and parent folders if they don't exist
      unless File.directory?(dirname)
        FileUtils.mkdir_p(dirname)
      end

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

      def set_hl(hl)
        @hl = hl
      end
    end
  end
end
