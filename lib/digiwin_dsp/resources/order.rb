# frozen_string_literal: true

module DigiwinDsp
  module Resources
    class Order < Base
      PATH = "/v1/SalesOrder/add"
      SERIALIZER = Serializers::SalesOrderSerializer
    end
  end
end
