# frozen_string_literal: true

require "logger"
require "uri"

module DigiwinDsp
  class Configuration
    DEFAULT_TIMEOUT = 10
    DEFAULT_OPEN_TIMEOUT = 5
    DEFAULT_ALLOWED_HOSTS = ["digiwindsp.digiwin.com"].freeze

    BASE_URLS = {
      sandbox: "https://digiwindsp.digiwin.com/DSP_UAT/api/DSP",
      production: "https://digiwindsp.digiwin.com/DSP/api/DSP"
    }.freeze

    # Webhook-subscription endpoint (DSPOOFFICIAL100) lives at a separate
    # base path from the SalesOrder endpoints.
    WEBHOOK_BASE_URLS = {
      sandbox: "https://digiwindsp.digiwin.com/DSP_UAT/api/webhook",
      production: "https://digiwindsp.digiwin.com/DSP/api/webhook"
    }.freeze

    attr_accessor :api_key, :platform_id, :environment, :logger,
                  :timeout, :open_timeout, :allowed_hosts
    attr_writer :base_url, :webhook_base_url

    def initialize
      @api_key           = ENV["DIGIWIN_DSP_API_KEY"]
      @platform_id       = ENV["DIGIWIN_DSP_PLATFORM_ID"]
      @environment       = ENV.fetch("DIGIWIN_DSP_ENV") { "sandbox" }.to_sym
      @base_url          = ENV["DIGIWIN_DSP_BASE_URL"]
      @webhook_base_url  = ENV["DIGIWIN_DSP_WEBHOOK_BASE_URL"]
      @timeout           = DEFAULT_TIMEOUT
      @open_timeout      = DEFAULT_OPEN_TIMEOUT
      @logger            = Logger.new(IO::NULL)
      @allowed_hosts     = DEFAULT_ALLOWED_HOSTS.dup
    end

    def base_url
      url = @base_url || resolve_default_base_url
      validate_url!(url)
      url
    end

    def webhook_base_url
      url = @webhook_base_url || resolve_default_webhook_base_url
      validate_url!(url)
      url
    end

    def validate!
      return unless api_key.nil? || api_key.to_s.empty?

      raise ConfigurationError,
            "api_key is required (set via DigiwinDsp.configure or DIGIWIN_DSP_API_KEY)"
    end

    private

    def resolve_default_base_url
      BASE_URLS.fetch(environment) do
        raise ConfigurationError,
              "unknown environment #{environment.inspect}; expected one of #{BASE_URLS.keys.inspect}"
      end
    end

    def resolve_default_webhook_base_url
      WEBHOOK_BASE_URLS.fetch(environment) do
        raise ConfigurationError,
              "unknown environment #{environment.inspect}; expected one of #{WEBHOOK_BASE_URLS.keys.inspect}"
      end
    end

    def validate_url!(url)
      uri = URI.parse(url)
      raise ConfigurationError, "base_url must use https (got #{uri.scheme.inspect})" unless uri.scheme == "https"
      return if allowed_hosts.include?(uri.host)

      raise ConfigurationError,
            "base_url host #{uri.host.inspect} is not in allowed_hosts #{allowed_hosts.inspect}; " \
            "add it via DigiwinDsp.configure { |c| c.allowed_hosts += [host] }"
    rescue URI::InvalidURIError => e
      raise ConfigurationError, "base_url is not a valid URI: #{e.message}"
    end
  end
end
