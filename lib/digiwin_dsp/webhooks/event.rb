# frozen_string_literal: true

require "json"

module DigiwinDsp
  module Webhooks
    # Base value-object for an inbound DSP webhook event. Subclasses add
    # action-specific accessors over the `request` payload but share the
    # JSON-parse + envelope-extract logic that lives here.
    class Event
      attr_reader :digi_header, :request, :raw

      def self.parse(raw_body)
        hash = parse_json(raw_body)
        request = extract_request(hash)
        new(digi_header: hash["digi_header"] || {}, request: request, raw: hash)
      end

      def self.parse_json(raw_body)
        # max_nesting mirrors the Client's parser DoS guard.
        JSON.parse(raw_body, max_nesting: 50)
      rescue JSON::ParserError => e
        raise ParseError, "invalid JSON: #{e.message}"
      end

      def self.extract_request(hash)
        raise ParseError, "envelope must be a JSON object" unless hash.is_a?(Hash)

        hash.dig("digi_body", "std_data", "parameter", "request") ||
          raise(ParseError, "envelope missing digi_body.std_data.parameter.request")
      end

      private_class_method :parse_json, :extract_request

      def initialize(digi_header:, request:, raw:)
        @digi_header = digi_header
        @request = request
        @raw = raw
      end
    end
  end
end
