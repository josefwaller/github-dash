require "spec_helper"
require "fileutils"
require "github_dash/cli"
require "sequel"

RSpec.describe GithubDash::CLI do

  let(:test_prompt) { TTY::TestPrompt.new }

  before :each do
    # Capture output from Thor
    allow(TTY::Prompt).to receive(:new).and_return(test_prompt)
    @out = test_prompt.output
    @in = test_prompt.input

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
    allow(test_prompt).to receive(:yes?).and_return(false)
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
  it "removes repositories with remove_repos" do
    allow(GithubDash::DataDepository).to receive(:get_following).and_return (["josefwaller/pycatan"])
    allow(GithubDash::DataDepository).to receive(:remove_repo).with("josefwaller/pycatan")
    allow(test_prompt).to receive(:multi_select).and_return(["josefwaller/pycatan"])
    VCR.use_cassette :pycatan do
      subject.remove_repos
    end
    expect(output).to include "removed 1 repo"
    expect(GithubDash::DataDepository).to have_received(:remove_repo).with("josefwaller/pycatan")
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
      allow(test_prompt).to receive(:ask).with(instance_of(String)).and_return("josefwaller")
      allow(test_prompt).to receive(:ask).with(instance_of(String), hash_including(:echo => false)).and_return(ENV['GITHUB_PASSWORD'])
      VCR.use_cassette :exampleprivate do
        subject.login
      end
      expect(output).to include("added josefwaller")
    end

    it "generates a new token if the token's name is taken" do

      allow(GithubDash).to receive(:add_user).with("josefwaller", ENV['GITHUB_PASSWORD'])
        .and_raise(Octokit::UnprocessableEntity)
      allow(GithubDash).to receive(:add_user).with(any_args, "github-dash token #{Time.now.to_i}")
      allow(test_prompt).to receive(:ask).with(/username/).and_return("josefwaller")
      allow(test_prompt).to receive(:ask).with(/password/, any_args).and_return(ENV['GITHUB_PASSWORD'])
      allow(test_prompt).to receive(:yes?).with(/Generate/).and_return(true)

      VCR.use_cassette :exampleprivate do
        subject.login
      end

      expect(GithubDash).to have_received(:add_user).with(any_args, "github-dash token #{Time.now.to_i}")
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
    it "deletes tokens" do

      mock_tokens = [
        {
          :name => "token_one",
          :token => "value_one"
        },
        {
          :name => "token_two",
          :token => "value_two"
        }
      ]
      token_one = "token_one"
      token_two = "token_two"
      allow(GithubDash::DataDepository).to receive(:delete_token).with(mock_tokens[0][:token])
      allow(GithubDash::DataDepository).to receive(:get_all_tokens).and_return(mock_tokens)
      allow(test_prompt).to receive(:multi_select).and_return([mock_tokens[0][:token]])
      subject.remove_tokens
      expect(GithubDash::DataDepository).to have_received(:delete_token).with(mock_tokens[0][:token])
    end
  end

  describe "Compare review" do
    before(:each) do
      subject.options = {
        :users => ["jhawthorn", "cbrunsdon"],
        :repo_name => "solidusio/solidus",
        :days => 10
      }
      VCR.use_cassette :solidus do
        subject.compare_review
      end
    end

    it "prints the repository name" do
      expect(output).to include("solidusio/solidus")
    end
    it "prints the users" do
      expect(output).to include("jhawthorn")
      expect(output).to include("cbrunsdon")
    end
  end
end
