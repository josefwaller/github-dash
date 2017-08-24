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
end
