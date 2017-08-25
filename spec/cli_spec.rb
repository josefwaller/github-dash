require "spec_helper"
require 'fileutils'
require "github_dash/cli"

RSpec.describe GithubDash::CLI do

  before :each do
    # Mock home dir
    ENV['HOME'] = File.expand_path "./tmp_home/"
    subject.create_settings_dir
    FileUtils.touch subject.repos_file_path

    # Capture output from Thor
    @out = StringIO.new
    @in = StringIO.new
    subject.set_hl HighLine.new(@in, @out)
  end
  after :each do
    FileUtils.rm_r "./tmp_home/" if File.directory? "./tmp_home"
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
    let(:client) { instance_double(Octokit::Client) }
    let(:token_resource) { double(Sawyer::Resource) }
    before(:each) do
      @filename = "#{ENV['HOME']}/.github_dash/token.txt"
      ENV['GITHUB_DASH_TOKEN'] ||= "ThisIsAnExampleGithubApiKey"
      ENV['GITHUB_PASSWORD'] ||= "MyExamplePassword"
      allow(token_resource).to receive(:token).and_return(ENV['GITHUB_DASH_TOKEN'])
    end

    it "generates a token when needed" do
      allow(File).to receive(:write).with(@filename, ENV['GITHUB_DASH_TOKEN'])
      # Stub Octokit::Client for authorization testing
      allow(Octokit::Client).to receive(:new).and_return(client)
      allow(client).to receive(:create_authorization).and_return(token_resource)
      allow(client).to receive(:login).and_return("mygithubusername")
      # Add input
      @in << "josefwaller\n"
      @in << "#{ENV['GITHUB_PASSWORD']}\n"
      @in.rewind
      VCR.use_cassette :exampleprivate do
        subject.login
      end
      expect(output).to include("logged in")
      expect(File).to have_received(:write).with(@filename, ENV['GITHUB_DASH_TOKEN'])
    end

    it "allows access to private repositories when given a token" do
      allow(File).to receive(:read).with(@filename).and_return(ENV['GITHUB_DASH_TOKEN'])
      allow(File).to receive(:file?).with(@filename).and_return(true)

      VCR.use_cassette :exampleprivate do
        subject.options = {:days => 7}
        subject.repo "josefwaller/exampleprivaterepository"
        expect(output).not_to include("argument error")
        expect(output).to include("josefwaller/exampleprivaterepository")
        expect(output).to include("commits from the last 7 days")
      end
    end
  end
end
