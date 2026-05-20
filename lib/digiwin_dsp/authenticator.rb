# frozen_string_literal: true

module DigiwinDsp
  class Authenticator
    HEADER_NAME = "DSP-api-key"

    def initialize(configuration = DigiwinDsp.configuration)
      @configuration = configuration
    end

    def auth_headers
      @configuration.validate!
      { HEADER_NAME => @configuration.api_key }
    end
  end
end
