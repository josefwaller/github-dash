require "spec_helper"

RSpec.describe GithubDash do
  it "has a version number" do
    expect(GithubDash::VERSION).not_to be nil
  end

  it "fetches a repositroy" do
    VCR.use_cassette "rails" do
      repo = GithubDash::fetch_repository "rails/rails"
      expect(repo.data.name).to eq("rails")
    end
  end

  it "raises an ArgumentError if the repository does not exist" do
    VCR.use_cassette "not_exist" do
      expect{GithubDash::fetch_repository "not-exist/does-not-exist"}.to raise_error(ArgumentError)
    end
  end

  context "given a repository" do
    before(:all) do
      VCR.insert_cassette "rails", :record => :new_episodes
      @repo = GithubDash::fetch_repository "rails/rails"
      @repo.update_commits
      @repo.update_pull_requests
    end
    after(:all) do
      VCR.eject_cassette "rails"
    end
    before(:each) do
      # Stub the date, so that 'commits in the last n days' doesn't
      #   rely on what day the test is being run
      allow(Date).to receive(:today).and_return Date.new(2017, 8, 14)
    end
    it "gets all PRs in the last day" do
      prs = @repo.get_pull_requests(days=1)
      expect(prs.length).to eq(0)
    end
    it "gets all PRs in the last week" do
      prs = @repo.get_pull_requests(days=7)
      expect(prs.length).to eq(10)
    end
    it "gets all PRs in the last month" do
      prs = @repo.get_pull_requests(days=30)
      expect(prs.length).to eq(67)
    end
    it "limits the number of PRs to 100 by default" do
      prs = @repo.get_pull_requests(days=1000)
      expect(prs.length).to eq(100)
    end
    it "limits the number of PRs when given a limit" do
      @repo.update_pull_requests 25
      prs = @repo.get_pull_requests(days=100)
      expect(prs.length).to eq(25)
    end
    it "gets all commits in the last day" do
      commits = @repo.get_commits(days=1)
      expect(commits.length).to eq(0)
    end
    it "gets all commits in the last week" do
      commits = @repo.get_commits(days=7)
      expect(commits.length).to eq(43)
    end
    it "gets all commits in the last month" do
      commits = @repo.get_commits(days=30)
      expect(commits.length).to eq(99)
    end
    it "limits the number of commits to 100 by default" do
      commits = @repo.get_commits(days=300)
      expect(commits.length).to eq(100)
    end
    it "limits the number of commits when given a limit" do
      @repo.update_commits 25
      commits = @repo.get_commits(days=100)
      expect(commits.length).to eq(25)
    end
  end
end
