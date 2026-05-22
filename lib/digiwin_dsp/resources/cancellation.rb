# frozen_string_literal: true

module DigiwinDsp
  module Resources
    class Cancellation < Base
      PATH = "/v1/SalesOrder/cancel"
      SERIALIZER = Serializers::CancellationSerializer
    end
  end
end
