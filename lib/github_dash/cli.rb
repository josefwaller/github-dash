require "thor"
require "github_dash"
require "pp"
require "tty-cursor"
require "tty-table"
require "tty-prompt"
require "pastel"

module GithubDash
  class CLI < Thor

    def initialize(*args)
      super
      @prompt = TTY::Prompt.new
      @pastel = Pastel.new
    end

    desc "add_repo REPO_NAME", "Adds a repository to the 'followed repositories' list"
    def add_repo(name)
      # Keep looping while the user is choosing different tokens
      token = nil
      loop do
        begin
          # Try to successfully add repository
          GithubDash::add_repo_to_following(name, token)
          @prompt.say "Added #{name} to followed repositories."
          break
        rescue ArgumentError
          # If repo is already follewed, just break
          @prompt.say "Repository is already followed!"
          break
        rescue Octokit::NotFound, Octokit::Unauthorized
          # Prompt user to enter another token
          @prompt.say "Could not find #{name} on github using #{@pastel.light_blue(token)}."
          ans = @prompt.yes? "Do you want to try with a different token?"

          # break if they said no
          break unless ans

          # Make menu for them to choose a toekn
          token = @prompt.select "Chose a token" do |menu|
            tokens = GithubDash::DataDepository.get_all_tokens
            # There must be at least 1 token to choose from
            if tokens.size < 1
              @prompt.say @pastel.red("No tokens added. Add a token with add_token.")
              return
            end
            # Add a choice per token
            tokens.map do |t|
              menu.choice(t[:name], t[:token])
            end
          end
        end
      end
    end

    desc "remove_repos", "Remove one repository from the 'followed repositories' list"
    def remove_repos
      # Prompt user for repos
      repos = @prompt.multi_select "Select which repos to remove" do |menu|
        GithubDash::DataDepository.get_following.each do |r|
          menu.choice r
        end
      end
      # Delete each one
      repos.each do |name|
        GithubDash::remove_repo_from_following(name)
      end
      @prompt.say "Removed #{repos.size} repositories."
    end

    desc "login", "Log into github to allow access to private repositories and increase API limit."
    def login

      # Prompt for username/password
      username = @prompt.ask("Enter username: ")
      password = @prompt.ask("Enter password: ", echo: false)

      GithubDash::add_user(username, password)
      @prompt.say "Added #{@pastel.bright_blue(username)}"
    end

    desc "add_token TOKEN", "Save a token and set it to be used first for all repositories"
    option :token_name, :aliases => [:n], :type => :string, :required => true
    def add_token(token)
      GithubDash::add_token(token, options[:token_name])
      @prompt.say "Added #{@pastel.bright_blue(options[:token_name])}"
    end

    desc "remove_tokens", "Delete one or more tokens"
    def remove_tokens

      # Get the tokens to remove
      remove_tokens = @prompt.multi_select "Select which tokens to remove" do |menu|
        GithubDash::DataDepository.get_all_tokens.each do |t|
          menu.choice t[:name], t[:token]
        end
      end
      @prompt.say "You are removing #{@pastel.bright_blue(remove_tokens.size)} tokens"

      # Double check
      if @prompt.yes?("Proceed: ")

        # Remove the tokens
        remove_tokens.each do |t|
          GithubDash::DataDepository.delete_token(t)
        end

        @prompt.say "Removed #{@pastel.bright_blue(remove_tokens.size)} tokens."
      else
        @prompt.say "Cancelled"
      end
    end

    desc "compare_review", "Print a comparative review of several user's commits on a certain repository"
    option :repo_name, :aliases => [:r], :type => :string, :required => true
    option :users, :aliases => [:u], :type => :array, :required => true
    option :days, :aliases => [:d], :type => :numeric, :default => 7
    def compare_review
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
      @prompt.say "\n"
      @prompt.say "Comparing commits from #{@pastel.bright_green(options[:repo_name])}" \
              " in the last #{@pastel.bright_green(options[:days])}".center(table.width)
      @prompt.say "\n"

      # Pastel colors only show up when the table is saved as a string first
      table_str = table.render(:unicode) do |r|
        r.filter = Proc.new do |val, row_index, col_index|
          if row_index == 0
            @pastel.yellow(val)
          else
            @pastel.bright_blue(val)
          end
        end
        r.padding = [0, 1]
      end

      # Print the table
      @prompt.say table_str
    end

    desc "following", "Show all the repopsitories the user is following"
    option :liveupdate, :aliases => [:l], :type => :boolean, :default => false
    def following

      # Gather all repos
      repos = {}
      GithubDash::get_following.each do |r|
        repos[r] = GithubDash::fetch_repository r
      end

      # Loop while liveupdating
      loop do
        begin
          # Create table
          table = TTY::Table.new(header: ["Repository", "PRs in the last week", "Commits in the last week"]) do |t|
            # Add each repo's data to the table
            repos.each do |r, val|
              repos.fetch(r).update_commits 100
              repos.fetch(r).update_pull_requests 100
              t << [val.data.full_name, val.get_pull_requests.size, val.get_commits.size]
            end
          end

          # Get the table's string
          table_str = table.render(:unicode) do |r|
            r.filter = Proc.new do |val, row, col|
              # The headers are yellow
              if row == 0
                @pastel.yellow(val)
              else
                # Set different colors for different columns
                case col
                when 0
                  @pastel.bright_blue val
                when 1
                  @pastel.bright_green val
                when 2
                  @pastel.bright_red val
                else
                  val
                end
              end
            end
            r.padding = [0, 1]
          end

          # Clear the screen and move the cursor to the too left
          #   Note: This must be done before printing the table
          if options[:liveupdate]
            print TTY::Cursor.clear_screen
            print TTY::Cursor.move_to
            print TTY::Cursor.hide
          end
          # Print the table
          @prompt.say table_str

          # If not live updating, break
          break unless options[:liveupdate]
          # Update every 10 seconds
          sleep 10
        ensure
          # If the user quits, show the cursor
          #   otherwise the cursor won't show in regular terminal
          print TTY::Cursor.show
        end
      end
    end

    option :days, :aliases => [:d], :type => :numeric, :default => 7
    desc "repo REPO_NAME", "Logs a bunch of information about a repository"
    def repo(name)
      # Fetch repo information
      repo = GithubDash::fetch_repository name

      # Create a table for this repo's informaion
      table = TTY::Table.new header: ["Commit Date", "Commit Title", "Commit Author"] do |t|
        repo.get_commits(options[:days]).each do |c|
          t << [c.commit.author.date, c.commit.message.split("\n").first, c.commit.author.name]
        end
      end

      # print title for the table
      @prompt.say "\n"
      @prompt.say @pastel.yellow(repo.data.full_name)
      @prompt.say "Commits from the last #{@pastel.bright_green(options[:days])} day#{"s" if options[:days] > 1}"
      table_str = table.render(:unicode) do |r|
        r.filter = Proc.new do |val, row_index, col_index|

          # Headers are yellow
          if row_index == 0
            @pastel.yellow(val)
          else
            # columns have different colors
            case col_index
            when 0
              @pastel.bright_blue(val)
            when 1
              @pastel.bright_red(val)
            when 2
              @pastel.green(val)
            else
              val
            end
          end
        end
        r.padding = [0, 1]
      end
      # Print the table
      @prompt.say table_str
    end
  end
end
