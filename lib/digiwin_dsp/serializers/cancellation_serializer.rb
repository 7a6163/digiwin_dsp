# frozen_string_literal: true

module DigiwinDsp
  module Serializers
    module CancellationSerializer
      extend Base

      REQUIRED_FIELDS = %w[
        platform_id create_datetime site_no form_no order_date
        sno product_no order_status
      ].freeze
    end
  end
end
