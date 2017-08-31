require "spec_helper"
require "github_dash/data_depository"
require "sequel"

RSpec.describe GithubDash::DataDepository do

  let(:database) { Sequel.sqlite }
  before(:each) do
    # For testing, always use a memory database
    allow(Sequel).to receive(:sqlite).and_return(database)
  end

  # Fill the database with example repositories for testing
  #   Also initilizes the tables, which would usually be done
  #   by DataDepository
  def init_example_db
    # Create repos table
    database.create_table :repos do
      primary_key :id
      String :name
      foreign_id :token_id
    end

    # Add example repositories
    r = database[:repos]
    r.insert(:name => "josefwaller/pycatan")
    r.insert(:name => "josefwaller/github_dash")
    r.insert(:name => "rails/rails")

    # Create tokens table
    database.create_table :tokens do
      primary_key :id
      String :token
      String :name
    end

    # Add example token
    t = database[:tokens]
    ENV['GITHUB_DASH_TOKEN'] ||= "ThisIsAnExampleGithubApiKey"
    t.insert(:token => ENV['GITHUB_DASH_TOKEN'])
  end

  describe "Repositories" do
    it "saves a repository" do
      GithubDash::DataDepository.add_repo("josefwaller/pycatan")

      expect(database[:repos].where(:name => "josefwaller/pycatan").all.count).to eq(1)
    end

    it "removes a repository" do
      init_example_db
      GithubDash::DataDepository.remove_repo("josefwaller/pycatan")
      expect(database[:repos].where(:name => "josefwaller/pycatan").all.count).to eq(0)
    end

    it "gets followed repositories" do
      init_example_db

      expect(GithubDash::DataDepository.get_following).to eq(["josefwaller/pycatan", "josefwaller/github_dash", "rails/rails"])
    end

    it "raises an error when removing an unfollowed repository" do
      expect{GithubDash::DataDepository.remove_repo("josefwaller/pycatan")}.to raise_error(ArgumentError)
    end

    it "raises an error when adding a followed repository" do
      init_example_db

      expect{GithubDash::DataDepository.add_repo("josefwaller/pycatan")}.to raise_error(ArgumentError)
    end

    it "saves a repository with the id of the token given" do
      init_example_db

      repo_one = "solidus/solidusio"
      GithubDash::DataDepository.add_repo(repo_one, ENV['GITHUB_DASH_TOKEN'])
      token_id = database[:tokens].where(:token => ENV['GITHUB_DASH_TOKEN']).first[:id]
      expect(database[:repos].where(:name => repo_one).first[:token_id]).to eq(token_id)

      repo_two = "django/django"
      GithubDash::DataDepository.save_token("this_is_my_newest_token", "New token name")
      GithubDash::DataDepository.add_repo(repo_two, "this_is_my_newest_token")
      token_id = database[:tokens].where(:token => "this_is_my_newest_token").first[:id]
      expect(database[:repos].where(:name => repo_two).first[:token_id]).to eq(token_id)
    end
    it "saves a repository with token_id = nil by default" do
      init_example_db

      GithubDash::DataDepository.add_repo("django/django")
      expect(database[:repos].where(:name => "django/django").first[:token_id]).to eq(nil)
    end
  end
  describe "Tokens" do
    let (:test_token) { "test_token" }

    it "saves a token" do
      GithubDash::DataDepository.save_token(test_token, "Test Token")

      expect(database[:tokens].all.count).to eq(1)
      expect(database[:tokens].all[0][:token]).to eq(test_token)
      expect(database[:tokens].all[0][:name]).to eq("Test Token")
    end
    it "fetches a token" do
      init_example_db
      expect(GithubDash::DataDepository.get_token).to eq(ENV['GITHUB_DASH_TOKEN'])
    end
    it "fetches the token with the highest id by default" do
      init_example_db
      database[:tokens].insert(:token => test_token)
      expect(GithubDash::DataDepository.get_token).to eq(test_token)
    end
    it "allows fetching the token which is a certain distance from the end" do
      init_example_db
      database[:tokens].insert(:token => test_token)
      expect(GithubDash::DataDepository.get_token(1)).to eq(ENV['GITHUB_DASH_TOKEN'])
    end
    it "saves a new token with the highest id" do
      init_example_db
      GithubDash::DataDepository.save_token(test_token, "Test token")
      expect(database[:tokens].order(:id).last[:token]).to eq(test_token)
    end
  end
end
