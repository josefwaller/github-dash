require "thor"
require "github_dash"
require "highline"
require "pp"
require "fileutils"
require "tty-cursor"

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

    desc "remove_repo REPO_NAME", "Removes a repository from the 'followed repositories' list"
    def remove_repo(name)

      create_settings_dir

      # Load the currently followed repos
      contents = File.read repos_file_path

      # Remove repos that match the repo to be removed
      removed_repo = false
      lines = contents.gsub(/\r\n/, "\n").split("\n").select do |line|
        removed_repo = true unless line.downcase != name.downcase
        !removed_repo
      end

      # Save new following
      File.write repos_file_path, lines.join("\n")

      # Tell the user whether it removed a repo or not
      if removed_repo
        @hl.say "Removed #{name.downcase}."
      else
        @hl.say "Could not remove #{name.downcase}. Not following"
      end
    end

    desc "following", "Show all the repopsitories the user is following"
    option :liveupdate, :aliases => [:l], :type => :boolean, :default => false
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
        repos = {}
        contents.split("\n").each do |r|
          repos[r] = GithubDash::fetch_repository r
        end
        loop do
          begin
            # Gather output from each repo
            all_output = ""
            repos.each_with_index do |(r, val), i|
              output = ""
              output += "<%= color('#{set_str_size(val.data.full_name, 30)}', YELLOW) %>"
              output += " | "
              output += "<%= color('#{set_str_size("#{val.get_pull_requests.size} PRs in the last week", 25)}', GREEN) %>"
              output += " | "
              output += "<%= color('#{set_str_size("#{val.get_commits.size} commits in the last week", 35)}', LIGHT_BLUE) %>"
              output += "\n"
              all_output += output
            end
            if options[:liveupdate]
              print TTY::Cursor.clear_screen
              print TTY::Cursor.move_to
              print TTY::Cursor.hide
            end
            @hl.say all_output
            break unless options[:liveupdate]
            sleep 10
          ensure
            print TTY::Cursor.show
          end
        end
      end
    end

    option :days, :aliases => [:d], :type => :numeric, :default => 7
    desc "repo REPO_NAME", "Logs a bunch of information about a repository"
    def repo(name)
      repo = GithubDash::fetch_repository(name)
      @hl.say "=== <%= color('#{repo.data.full_name}', YELLOW) %> ==="
      @hl.say "=============================="
      @hl.say "Commits from the last <%= color('#{options[:days]}', GREEN) %> day#{"s" if options[:days] > 1}."
      @hl.say "---------"
      repo.get_commits(days=options[:days]).each do |c|
        output = ""
        output += "[<%= color('#{c.commit.author.date}', LIGHT_BLUE) %>] - "
        output += "<%= color('#{c.commit.message.split("\n").first}', YELLOW) %> "
        output += "(by <%= color('#{c.commit.author.name}', GREEN) %>)"
        @hl.say output
        @hl.say "-----------------------"
      end
      @hl.say "=============================="
      @hl.say "PRs from the last <%= color('#{options[:days]}', GREEN) %> day#{"s" if options[:days] > 1}."
      @hl.say "---------------"
      repo.get_pull_requests(days=options[:days]).each do |pr|
        output = ""
        output += "[<%= color('#{pr.updated_at}', LIGHT_BLUE) %>] - "
        output += "<%= color('#{pr.title}', YELLOW) %> "
        output += "(by <%= color('#{pr.user.login}', GREEN) %>)."
        @hl.say output
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

      def set_hl(hl)
        @hl = hl
      end
    end
  end
end
