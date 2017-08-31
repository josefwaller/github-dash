require "spec_helper"
require "fileutils"
require "github_dash/cli"
require "sequel"

RSpec.describe GithubDash::CLI do

  before :each do
    # Capture output from Thor
    @out = StringIO.new
    @in = StringIO.new
    subject.set_hl HighLine.new(@in, @out)

    allow(Sequel).to receive(:sqlite).and_return(Sequel.sqlite)
  end

  def output
    return @out.string.downcase.gsub(/\e\[[0-9]*m/, "")
  end

  it "logs repo information" do
    VCR.use_cassette :pycatan do
      subject.options = {days: 7}
      subject.repo "josefwaller/pycatan"
      expect(output).to include("josefwaller/pycatan")
    end
  end
  it "uses the days option" do
    VCR.use_cassette :githubdash do
      subject.options = {days: 10}
      subject.repo "josefwaller/github-dash"
      expect(output).to include("commits from the last 10 days")
    end
  end
  it "uses day with singular days" do
    VCR.use_cassette :githubdash do
      subject.options = {days: 1}
      subject.repo "josefwaller/github-dash"
      expect(output).to include("commits from the last 1 day")
    end
  end
  it "adds repositories" do
    VCR.use_cassette :pycatan do
      subject.add_repo "josefwaller/pycatan"
    end
    expect(output).to include "added josefwaller/pycatan"
  end
  it "shouldn't add a repository twice" do
    VCR.use_cassette :pycatan do
      subject.add_repo "josefwaller/pycatan"
      subject.add_repo "josefwaller/pycatan"
    end
    expect(output).to include "repository is already followed"
  end
  it "doesn't add a repository that does not exist" do
    # Out: Do you want to try with a different token? [Y/n]
    @in << "n"
    @in.rewind
    VCR.use_cassette :not_exist, :record => :new_episodes do
      subject.add_repo "doesnot/exist"
    end
    expect(output).to include "could not find doesnot/exist on github"
  end
  it "logs following repositories" do
    VCR.use_cassette :pycatan do
      subject.add_repo "josefwaller/pycatan"
    end
    VCR.use_cassette :githubdash do
      subject.add_repo "josefwaller/github-dash"
    end
    VCR.use_cassette :githubdash do
      VCR.use_cassette :pycatan do
        subject.following
      end
    end
    expect(output).to include "josefwaller/pycatan"
    expect(output).to include "josefwaller/github-dash"
  end
  it "removes repositories with remove_repo" do
    VCR.use_cassette :pycatan do
      subject.add_repo "josefwaller/pycatan"
      subject.remove_repo "josefwaller/pycatan"
    end
    expect(output).to include "removed josefwaller/pycatan"
  end
  it "warns the user if they try to remove a repository they are not following" do
    subject.remove_repo "josefwaller/pycatan"
    expect(output).to include "could not remove josefwaller/pycatan"
    expect(output).to include "not following"
  end

  describe "Authentication" do
    let(:token_resource) { double(Sawyer::Resource) }
    before(:each) do
      ENV['GITHUB_DASH_TOKEN'] ||= "ThisIsAnExampleGithubApiKey"
      ENV['GITHUB_PASSWORD'] ||= "MyExamplePassword"
      allow(token_resource).to receive(:token).and_return(ENV['GITHUB_DASH_TOKEN'])
    end

    it "generates a token when needed" do
      # Stub Octokit::Client for authorization testing
      client = instance_double(Octokit::Client)
      allow(client).to receive(:create_authorization).and_return(token_resource)
      allow(client).to receive(:login).and_return("mygithubusername")
      allow(Octokit::Client).to receive(:new).and_return(client)
      # Add input
      @in << "josefwaller\n"
      @in << "#{ENV['GITHUB_PASSWORD']}\n"
      @in.rewind
      VCR.use_cassette :exampleprivate do
        subject.login
      end
      expect(output).to include("added josefwaller")
    end

    it "allows access to private repositories when given a token" do
      VCR.use_cassette :exampleprivate do
        subject.options = {:days => 7}
        subject.repo "josefwaller/exampleprivaterepository"
        expect(output).not_to include("argument error")
        expect(output).to include("josefwaller/exampleprivaterepository")
        expect(output).to include("commits from the last 7 days")
      end
    end

    it "saves a token" do
      subject.options = {token_name: "test_token"}
      subject.add_token "asdfasdfasdfasdf"
      expect(output).to include("added test_token")
    end
  end
end
