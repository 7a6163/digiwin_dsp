# frozen_string_literal: true

module DigiwinDsp
  module Resources
    class Cancellation
      PATH = "/v1/SalesOrder/cancel"

      def self.create(records, idempotency_key: nil, digi_header: nil)
        new.create(records, idempotency_key: idempotency_key, digi_header: digi_header)
      end

      def initialize(client = Client.new)
        @client = client
      end

      def create(records, idempotency_key: nil, digi_header: nil)
        body = Serializers::CancellationSerializer.serialize(records, digi_header: digi_header)
        response = @client.post(PATH, body, idempotency_key: idempotency_key)
        response.fetch("response_detail") do
          raise DigiwinDsp::ServerError, "DSP returned Status=Success without response_detail"
        end
      end
    end
  end
end
