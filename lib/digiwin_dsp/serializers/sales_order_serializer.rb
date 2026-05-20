# frozen_string_literal: true

module DigiwinDsp
  module Serializers
    module SalesOrderSerializer
      extend Base

      REQUIRED_FIELDS = %w[
        platform_id create_datetime site_no form_no order_date
        buyer_name receiver_name pay_type shipping_type tax_type
        sno form_subno product_no product_name unit
        qty free_qty price subtotal payment
        order_status last_record
      ].freeze
    end
  end
end
