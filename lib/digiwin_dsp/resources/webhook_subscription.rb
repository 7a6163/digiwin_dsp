# frozen_string_literal: true

module DigiwinDsp
  module Resources
    # Registers a webhook callback URL with DSP (DSPOOFFICIAL100,
    # POST /v1/webhook on the webhook_base_url).
    #
    # Not a Resources::Base subclass — the request envelope is a single
    # `request` object (not `request_detail[]` array), the fields are
    # explicit kwargs (not an arbitrary hash), and it targets the
    # webhook_base_url instead of base_url.
    class WebhookSubscription
      PATH = "/v1/webhook"
      DEFAULT_PROD = "OFFICIALWEBSITE"
      ACTIONS = %w[
        product/inventory_update
        wms/logistics/package/update
        invoice/update
      ].freeze
      ADDRESS_MAX_LENGTH = 500

      def self.create(action:, address:, platform_id: nil, prod: DEFAULT_PROD)
        new.create(action: action, address: address, platform_id: platform_id, prod: prod)
      end

      def initialize(client = nil)
        @client = client || Client.new(base_url: DigiwinDsp.configuration.webhook_base_url)
      end

      def create(action:, address:, platform_id: nil, prod: DEFAULT_PROD)
        validate_args!(action: action, address: address)
        body = build_body(action: action, address: address, platform_id: platform_id, prod: prod)
        response = @client.post(PATH, body)
        response.dig("std_data", "response") ||
          raise(DigiwinDsp::ServerError, "DSP returned execution.code=0 without std_data.response")
      end

      private

      def validate_args!(action:, address:)
        unless ACTIONS.include?(action)
          raise DigiwinDsp::ValidationError,
                "action must be one of #{ACTIONS.inspect} (got #{action.inspect})"
        end
        raise DigiwinDsp::ValidationError, "address is required" if address.nil? || address.to_s.empty?
        return unless address.length > ADDRESS_MAX_LENGTH

        raise DigiwinDsp::ValidationError,
              "address must be <= #{ADDRESS_MAX_LENGTH} chars (got #{address.length})"
      end

      def build_body(action:, address:, platform_id:, prod:)
        resolved = resolve_platform_id(platform_id)
        request = { "prod" => prod, "platform_id" => resolved, "action" => action, "address" => address }
        { "digi_body" => { "std_data" => { "parameter" => { "request" => request } } } }
      end

      def resolve_platform_id(explicit)
        id = explicit || DigiwinDsp.configuration.platform_id
        return id unless id.nil? || id.to_s.empty?

        raise DigiwinDsp::ConfigurationError,
              "platform_id is required (set via configure or pass explicitly)"
      end
    end
  end
end
