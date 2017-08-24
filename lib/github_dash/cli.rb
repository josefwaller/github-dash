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

    desc "repo REPO_NAME", "Logs a bunch of information about a repository"
    def repo(name)
      repo = GithubDash::fetch_repository(name)
      @hl.say "=== #{repo.data.full_name} ==="
      @hl.say "=============================="
      @hl.say "Last week"
      @hl.say "---------"
      repo.get_commits(days=7).each do |c|
        @hl.say "[#{c.commit.author.date}] - #{c.commit.message.split("\n").first} (by #{c.commit.author.name})"
        @hl.say "-----------------------"
      end
      @hl.say "=============================="
      @hl.say "Last week's PRs"
      @hl.say "---------------"
      repo.get_pull_requests(days=7).each do |pr|
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
