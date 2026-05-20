# frozen_string_literal: true

require "zeitwerk"

module DigiwinDsp
  class Error < StandardError
    attr_reader :code, :dsp_message, :request_id, :http_status, :response_body

    def initialize(message = nil, code: nil, dsp_message: nil, request_id: nil, http_status: nil, response_body: nil)
      super(message)
      @code          = code
      @dsp_message   = dsp_message
      @request_id    = request_id
      @http_status   = http_status
      @response_body = response_body
    end
  end

  class ConfigurationError    < Error; end
  class AuthenticationError   < Error; end
  class ValidationError       < Error; end
  class RateLimitError        < Error; end
  class ServerError           < Error; end
  class NetworkError          < Error; end
  class DuplicateRequestError < Error; end

  class << self
    attr_writer :configuration

    def configuration
      @configuration ||= Configuration.new
    end

    def configure
      yield(configuration)
    end

    def reset_configuration!
      @configuration = Configuration.new
    end
  end
end

loader = Zeitwerk::Loader.for_gem
loader.setup
