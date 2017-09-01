require "thor"
require "github_dash"
require "highline"
require "pp"
require "fileutils"
require "tty-cursor"
require "tty-table"
require "pastel"

module GithubDash
  class CLI < Thor

    def initialize(*args)
      super
      @hl = HighLine.new
      @client = nil
    end

    desc "add_repo REPO_NAME", "Adds a repository to the 'followed repositories' list"
    def add_repo(name)
      token = nil
      loop do
        begin
          GithubDash::add_repo_to_following(name, token)
          @hl.say "Added #{name} to followed repositories."
          break
        rescue ArgumentError
          @hl.say "Repository is already followed!"
          break
        rescue Octokit::NotFound, Octokit::Unauthorized
          @hl.say "Could not find #{name} on github using #{token}."
          ans = @hl.ask "Do you want to try with a different token? [Y/n]"

          break if ans.downcase != "y"

          @hl.choose do |menu|
            tokens = GithubDash::DataDepository.get_all_tokens
            tokens.each do |t|
              menu.choice "#{t[:name]} (#{t[:token]})" do
                token = t[:token]
              end
            end
          end
        end
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
    option :token_name, :aliases => [:n], :type => :string, :required => true
    def add_token(token)
      GithubDash::add_token(token, options[:token_name])
      @hl.say "Added #{options[:token_name]}"
    end

    desc "compare_review", "Print a comparative review of several user's commits on a certain repository"
    option :repo_name, :aliases => [:r], :type => :string, :required => true
    option :users, :aliases => [:u], :type => :array, :required => true
    option :days, :aliases => [:d], :type => :numeric, :default => 7
    def compare_review

      # Get pastel for color
      pastel = Pastel.new

      # First, create headers, which is just
      #   the user's option aligned center
      headers = options[:users].map {|u| {value: u, alignment: :center}}

      # Create a new table
      table = TTY::Table.new :header => headers do |t|

        # Create empty 2D array
        rows = Array.new(options[:users].count) { [] }

        # Fetch the repo
        repo = GithubDash::fetch_repository options[:repo_name]

        # Get the commit messages for each user
        options[:users].each_with_index do |val, i|
          commits = repo.get_commits(10, val)

          # Add their messages to the rwos array
          commits.each_with_index do |c, c_i|
            rows[i].push c.commit.message.split("\n").first
          end
        end
        # Pads the rows until they are all equal size
        mx_size = rows.map(&:size).max
        rows.each {|r| r.fill(nil, r.count, mx_size - r.count) }

        # Since we have one user per row, but the table will have one user per column,
        #   transpose the rows before adding them
        rows.transpose.each do |r|
          t << r
        end
      end

      # Tell user what repos we are comparing
      @hl.say "\n"
      @hl.say "Comparing commits from #{pastel.bright_green(options[:repo_name])}" \
              " in the last #{pastel.bright_green(options[:days])}".center(table.width)
      @hl.say "\n"

      # Pastel colors only show up when the table is saved as a string first
      table_str = table.render(:unicode) do |r|
        r.filter = Proc.new do |val, row_index, col_index|
          if row_index == 0
            pastel.yellow(val)
          else
            pastel.bright_blue(val)
          end
        end
        r.padding = [0, 1]
      end

      # Print the table
      @hl.say table_str
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
    end
  end
end
