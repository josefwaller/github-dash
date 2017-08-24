require "thor"
require "github_dash"
require "highline"
require "pp"

module GithubDash
  class CLI < Thor

    def initialize(*args)
      super
      @hl = HighLine.new
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
      def set_hl(hl)
        @hl = hl
      end
    end
  end
end
