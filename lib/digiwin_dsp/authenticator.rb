# frozen_string_literal: true

module DigiwinDsp
  class Authenticator
    HEADER_NAME = "DSP-api-key"

    def initialize(configuration = DigiwinDsp.configuration)
      @configuration = configuration
    end

    # Validation lives in Client#post (called per-request). Authenticator
    # only ran validate! once per connection lifetime due to Client's
    # memoized #default_headers, so the redundant call was misleading.
    def auth_headers
      { HEADER_NAME => @configuration.api_key }
    end
  end
end
