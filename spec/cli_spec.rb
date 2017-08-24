require "spec_helper"
require 'fileutils'
require "github_dash/cli"

RSpec.describe GithubDash::CLI do

  before :each do
    # Mock home dir
    ENV['HOME'] = File.expand_path "./tmp_home/"

    # Capture output from Thor
    @out = StringIO.new
    @in = StringIO.new
    subject.set_hl HighLine.new(@in, @out)
  end
  after :each do
    FileUtils.rm_r "./tmp_home/" if File.directory? "./tmp_home"
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
      expect(@out.string).to include("Commits from the last 10 days")
    end
  end
  it "uses day with singular days" do
    VCR.use_cassette :githubdash do
      subject.options = {days: 1}
      subject.repo "josefwaller/github-dash"
      expect(@out.string).to include("Commits from the last 1 day")
    end
  end
end
