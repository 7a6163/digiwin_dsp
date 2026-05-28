# frozen_string_literal: true

module DigiwinDsp
  module Webhooks
    # Fired by DSP when one or more ERP-issued invoices land. Unlike the
    # other two events, the request payload is an Array (DSP batches
    # invoices). See docs/dsp-specs/DSPOOFFICIAL100.yaml under
    # "發票資料更新 invoice/update".
    class InvoiceUpdate < Event
      def self.parse(raw_body)
        event = super
        raise ParseError, "invoice/update payload must be an array of invoice records" unless event.request.is_a?(Array)

        event
      end

      def invoices = request
    end
  end
end
