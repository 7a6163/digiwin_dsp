# frozen_string_literal: true

module DigiwinDsp
  module Serializers
    module InvoiceSerializer
      extend Base

      REQUIRED_FIELDS = %w[
        platform_id create_datetime site_no form_no
        invoice_no invoice_date invoice_time invoice_status invoice_type random_code
        order_status
      ].freeze
    end
  end
end
