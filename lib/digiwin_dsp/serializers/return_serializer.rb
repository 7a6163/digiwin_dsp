# frozen_string_literal: true

module DigiwinDsp
  module Serializers
    module ReturnSerializer
      extend Base

      REQUIRED_FIELDS = %w[
        platform_id create_datetime site_no form_no form_subno
        original_form_no tax_type sno product_no
        qty free_qty price subtotal payment order_status
        returner_name returner_address returner_phone returner_zip_code
      ].freeze
    end
  end
end
