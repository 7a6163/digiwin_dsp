# frozen_string_literal: true

require "vcr"

VCR.configure do |c|
  c.cassette_library_dir = File.expand_path("../fixtures/cassettes", __dir__)
  c.hook_into :webmock
  c.configure_rspec_metadata!

  # Strip credentials before writing cassettes. Replaced with placeholders
  # so committed cassettes don't leak the UAT api_key.
  c.filter_sensitive_data("<DSP_API_KEY>") { ENV["DIGIWIN_DSP_API_KEY"] }
  c.filter_sensitive_data("<PLATFORM_ID>") { ENV["DIGIWIN_DSP_PLATFORM_ID"] }

  # Default to replay-only. Set RECORD_CASSETTES=1 to overwrite all
  # cassettes with fresh real-UAT responses (requires DIGIWIN_DSP_API_KEY
  # + DIGIWIN_DSP_PLATFORM_ID in the env).
  c.default_cassette_options = {
    record: ENV["RECORD_CASSETTES"] ? :all : :none,
    match_requests_on: %i[method uri]
  }
end
