# frozen_string_literal: true

module DigiwinDsp
  module Resources
    class Return < Base
      PATH = "/v1/SalesOrder/return"
      SERIALIZER = Serializers::ReturnSerializer
    end
  end
end
