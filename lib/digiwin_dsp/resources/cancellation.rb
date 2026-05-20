# frozen_string_literal: true

module DigiwinDsp
  module Resources
    class Cancellation
      PATH = "/v1/SalesOrder/cancel"

      def self.create(records, **)
        new.create(records, **)
      end

      def initialize(client = Client.new)
        @client = client
      end

      def create(records, idempotency_key: nil, digi_header: nil)
        body = Serializers::CancellationSerializer.serialize(records, digi_header: digi_header)
        response = @client.post(PATH, body, idempotency_key: idempotency_key)
        response["response_detail"]
      end
    end
  end
end
