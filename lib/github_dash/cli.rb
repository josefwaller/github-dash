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
      @client = nil
    end

    desc "add_repo REPO_NAME", "Adds a repository to the 'followed repositories' list"
    def add_repo(name)
      begin
        GithubDash::add_repo_to_following(name)
        @hl.say "Added #{name} to followed repositories."
      rescue ArgumentError
        @hl.say "Repository is already followed!"
      rescue Octokit::NotFound
        @hl.say "Could not find #{name} on github. Do you need to log in first?"
      end
    end

    desc "remove_repo REPO_NAME", "Removes a repository from the 'followed repositories' list"
    def remove_repo(name)
      begin
        GithubDash::remove_repo_from_following(name)
        @hl.say "Removed #{name.downcase}."
      rescue ArgumentError
        @hl.say "Could not remove #{name.downcase}. Not following."
      end
    end

    desc "login", "Log into github to allow access to private repositories and increase API limit."
    def login

      # Prompt for username/password
      username = @hl.ask("Enter username: ")
      password = @hl.ask("Enter password: ") {|q| q.echo = "X"}

      GithubDash::add_user(username, password)
      @hl.say "Added #{username}"
    end

    desc "add_token TOKEN", "Save a token and set it to be used first for all repositories"
    def add_token(token)
      GithubDash::add_token(token)
      @hl.say "Added #{token}"
    end

    desc "following", "Show all the repopsitories the user is following"
    option :liveupdate, :aliases => [:l], :type => :boolean, :default => false
    def following

      repos = {}
      GithubDash::get_following.each do |r|
        repos[r] = GithubDash::fetch_repository r
      end

      loop do
        begin
          # Gather output from each repo
          all_output = ""

          # Add headers
          all_output += "| "
          all_output += set_str_size("Repository", 30)
          all_output += " | "
          all_output += set_str_size("PRs in the last week", 25)
          all_output += " | "
          all_output += set_str_size("Commits in the last week", 35)
          all_output += " |"
          all_output += "\n"
          all_output += "| "
          all_output += "-" * (30 + 25 + 35 + 6)
          all_output += " |"
          all_output += "\n"
          repos.each_with_index do |(r, val), i|
            repos.fetch(r).update_commits 100
            repos.fetch(r).update_pull_requests 100

            output = "| "
            output += "<%= color('#{set_str_size(val.data.full_name, 30)}', YELLOW) %>"
            output += " | "
            output += "<%= color('#{set_str_size("#{val.get_pull_requests.size} PRs in the last week", 25)}', GREEN) %>"
            output += " | "
            output += "<%= color('#{set_str_size("#{val.get_commits.size} commits in the last week", 35)}', LIGHT_BLUE) %>"
            output += " |\n"
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

    option :days, :aliases => [:d], :type => :numeric, :default => 7
    desc "repo REPO_NAME", "Logs a bunch of information about a repository"
    def repo(name)
      # Fetch repo information
      repo = GithubDash::fetch_repository name
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
            # Minor helper method for setting string size
      #   will trunicate string if too big or add spaces if too small
      def set_str_size(str, size)
        str.ljust(size)[0..size]
      end
      
      def set_hl(hl)
        @hl = hl
      end
    end
  end
end
