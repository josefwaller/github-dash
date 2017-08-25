require "bundler/setup"
require "github_dash"
require "webmock/rspec"
require "vcr"

# Enable WebMock
WebMock.disable_net_connect!(allow_localhost: false)

WebMock.stub_request(:any, "https://api.github.com")
  .to_return(status: 201, body: {token: ENV['GITHUB_DASH_TEST_API_KEY']}.to_s, headers: {})

# Enable VCR
VCR.configure do |c|
  c.cassette_library_dir = "spec/cassettes"
  c.hook_into :webmock
  c.filter_sensitive_data('ThisIsAnExampleGithubApiKey') { ENV['GITHUB_DASH_TOKEN'] }
  c.filter_sensitive_data('ThisIsAGithubPassword') { ENV['GITHUB_PASSWORD'] }
end

RSpec.configure do |config|
  # Enable flags like --only-failures and --next-failure
  config.example_status_persistence_file_path = ".rspec_status"

  # Disable RSpec exposing methods globally on `Module` and `main`
  config.disable_monkey_patching!

  config.expect_with :rspec do |c|
    c.syntax = :expect
  end
end
