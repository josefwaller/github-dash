require "spec_helper"
require "github_dash/data_depository"

RSpec.describe GithubDash::DataDepository do

  describe "Repositories" do

    let(:filepath) { "#{ENV['HOME']}/.github_dash/repositories.txt" }
    let(:file) { StringIO.new }
    before(:each) do
      # Allow the creation of the repositories file
      allow(File).to receive(:open).with(filepath, "w").and_return(StringIO.new)

      # Mock writing to a file when saving a new repo
      allow(File).to receive(:open).with(filepath, "a+").and_yield(file)
      update_file_contents
    end

    def update_file_contents
      file.rewind
      allow(File).to receive(:read).with(filepath).and_return(file.read)
      file.rewind
    end

    it "saves a repository" do
      GithubDash::DataDepository.add_repo("josefwaller/pycatan")

      expect(File).to have_received(:open).with(filepath, "a+")

      expect(file.string).to include("josefwaller/pycatan")
    end

    it "removes a repository" do
      # Fill example file
      file.puts "josefwaller/pycatan"
      file.puts "josefwaller/github_dash"
      file.puts "rails/rails"
      update_file_contents

      allow(File).to receive(:write).with(filepath, "josefwaller/github_dash\nrails/rails")

      GithubDash::DataDepository.remove_repo("josefwaller/pycatan")

      expect(File).to have_received(:write).with(filepath, "josefwaller/github_dash\nrails/rails")
    end

    it "gets followed repositories" do
      file.puts "josefwaller/pycatan"
      file.puts "josefwaller/github_dash"
      update_file_contents

      expect(GithubDash::DataDepository.get_following).to eq(["josefwaller/pycatan", "josefwaller/github_dash"])
    end

    it "raises an error when removing an unfollowed repository" do
      expect{GithubDash::DataDepository.remove_repo("josefwaller/pycatan")}.to raise_error(ArgumentError)
    end

    it "raises an error when adding a followed repository" do
      file.puts "josefwaller/pycatan"
      update_file_contents

      expect{GithubDash::DataDepository.add_repo("josefwaller/pycatan")}.to raise_error(ArgumentError)
    end
  end
  describe "Tokens" do

    let (:filepath) { "#{ENV['HOME']}/.github_dash/token.txt" }
    it "saves a token" do
      allow(File).to receive(:write).with(filepath, "test_token")

      GithubDash::DataDepository.save_token("test_token")

      expect(File).to have_received(:write).with(filepath, "test_token")
    end
    it "fetches a token" do
      allow(File).to receive(:read).with(filepath).and_return("test_token")

      expect(GithubDash::DataDepository.get_token).to eq("test_token")
    end
  end
end
