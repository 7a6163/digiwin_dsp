# frozen_string_literal: true

require "logger"

module DigiwinDsp
  class Configuration
    DEFAULT_TIMEOUT = 10
    DEFAULT_OPEN_TIMEOUT = 5

    BASE_URLS = {
      sandbox: "https://digiwindsp.digiwin.com/DSP_UAT/api/DSP",
      production: "https://digiwindsp.digiwin.com/DSP/api/DSP"
    }.freeze

    attr_accessor :api_key, :api_secret, :platform_id, :environment, :logger, :timeout, :open_timeout
    attr_writer :base_url

    def initialize
      @api_key      = ENV.fetch("DIGIWIN_DSP_API_KEY", nil)
      @api_secret   = ENV.fetch("DIGIWIN_DSP_API_SECRET", nil)
      @platform_id  = ENV.fetch("DIGIWIN_DSP_PLATFORM_ID", nil)
      @environment  = ENV.fetch("DIGIWIN_DSP_ENV", "sandbox").to_sym
      @base_url     = ENV.fetch("DIGIWIN_DSP_BASE_URL", nil)
      @timeout      = DEFAULT_TIMEOUT
      @open_timeout = DEFAULT_OPEN_TIMEOUT
      @logger       = Logger.new(IO::NULL)
    end

    def base_url
      return @base_url if @base_url

      BASE_URLS.fetch(environment) do
        raise ConfigurationError,
              "unknown environment #{environment.inspect}; expected one of #{BASE_URLS.keys.inspect}"
      end
    end

    def validate!
      return unless api_key.nil? || api_key.to_s.empty?

      raise ConfigurationError,
            "api_key is required (set via DigiwinDsp.configure or DIGIWIN_DSP_API_KEY)"
    end
  end
end
