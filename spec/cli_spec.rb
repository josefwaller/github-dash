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

  def strip_color(str)
    return str.gsub(/\e\[[0-9]*m/, "")
  end

  it "logs repo information" do
    VCR.use_cassette :pycatan do
      subject.options = {days: 7}
      subject.repo "josefwaller/pycatan"
      expect(@out.string).to include("josefwaller/PyCatan")
    end
  end
  it "uses the days option" do
    VCR.use_cassette :githubdash do
      subject.options = {days: 10}
      subject.repo "josefwaller/github-dash"
      expect(strip_color @out.string).to include("Commits from the last 10 days")
    end
  end
  it "uses day with singular days" do
    VCR.use_cassette :githubdash do
      subject.options = {days: 1}
      subject.repo "josefwaller/github-dash"
      expect(strip_color @out.string).to include("Commits from the last 1 day")
    end
  end
  it "adds repositories" do
    VCR.use_cassette :pycatan do
      subject.add_repo "josefwaller/pycatan"
    end
    expect(@out.string).to include "Added josefwaller/pycatan"
  end
  it "shouldn't add a repository twice" do
    VCR.use_cassette :pycatan do
      subject.add_repo "josefwaller/pycatan"
      subject.add_repo "josefwaller/pycatan"
    end
    expect(@out.string).to include "Repository is already followed"
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
    expect(strip_color @out.string).to include "josefwaller/PyCatan"
    expect(strip_color @out.string).to include "josefwaller/github-dash"
  end
  it "removes repositories with remove_repo" do
    VCR.use_cassette :pycatan do
      subject.add_repo "josefwaller/pycatan"
      subject.remove_repo "josefwaller/pycatan"
    end
    expect(@out.string).to include "Removed josefwaller/pycatan"
  end
  it "warns the user if they try to remove a repository they are not following" do
    subject.remove_repo "josefwaller/pycatan"
    expect(@out.string).to include "Could not remove josefwaller/pycatan"
    expect(@out.string).to include "Not following"
  end
end
