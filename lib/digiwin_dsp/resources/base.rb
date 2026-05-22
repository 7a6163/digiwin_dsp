# frozen_string_literal: true

module DigiwinDsp
  module Resources
    # Subclasses declare two constants:
    #   PATH       — endpoint path (e.g. "/v1/SalesOrder/add")
    #   SERIALIZER — a module/class responding to `.serialize(records, digi_header:)`
    #
    # Base then handles the .create class shortcut, the instance #create flow,
    # and the response_detail safety check.
    class Base
      def self.create(records, idempotency_key: nil, digi_header: nil)
        new.create(records, idempotency_key: idempotency_key, digi_header: digi_header)
      end

      def initialize(client = Client.new)
        @client = client
      end

      def create(records, idempotency_key: nil, digi_header: nil)
        body = self.class::SERIALIZER.serialize(records, digi_header: digi_header)
        response = @client.post(self.class::PATH, body, idempotency_key: idempotency_key)
        response.fetch("response_detail") do
          raise DigiwinDsp::ServerError, "DSP returned Status=Success without response_detail"
        end
      end
    end
  end
end
