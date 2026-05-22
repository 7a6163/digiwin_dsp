# frozen_string_literal: true

module DigiwinDsp
  module Resources
    class Invoice < Base
      PATH = "/v1/SalesOrder/invoice"
      SERIALIZER = Serializers::InvoiceSerializer
    end
  end
end
