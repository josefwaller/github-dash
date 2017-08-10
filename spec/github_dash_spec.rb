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
end
