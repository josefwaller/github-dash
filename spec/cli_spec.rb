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
      subject.repo "josefwaller/pycatan"
      expect(@out.string).to include("josefwaller/PyCatan")
    end
  end
end
