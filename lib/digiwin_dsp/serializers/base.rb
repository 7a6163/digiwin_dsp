# frozen_string_literal: true

require "date"

module DigiwinDsp
  module Serializers
    # Mix into a serializer module via `extend Base`. The hosting module must
    # define a REQUIRED_FIELDS constant (array of string field names).
    module Base
      # strftime formats from docs/dsp-specs/*.yaml. Checked on every endpoint
      # whenever the field is present; blank optional fields are skipped.
      FIELD_FORMATS = {
        "create_datetime" => "%Y-%m-%d %H:%M:%S",
        "order_date" => "%Y%m%d",
        "invoice_date" => "%Y%m%d",
        "order_expect_shipping_date" => "%Y%m%d",
        "invoice_time" => "%H:%M:%S"
      }.freeze

      # Spec-style labels for error messages: "%Y-%m-%d" -> "YYYY-MM-DD".
      # %m (month) and %M (minute) both read "MM", as in the DSP docs.
      FORMAT_LABELS = { "%Y" => "YYYY", "%m" => "MM", "%d" => "DD", "%H" => "HH", "%M" => "MM", "%S" => "SS" }.freeze

      def serialize(records, digi_header: nil)
        normalized = normalize(records)
        validate!(normalized)
        wrap(normalized, digi_header)
      end

      private

      def normalize(records)
        list = records.is_a?(Array) ? records : [records]
        raise ValidationError, "records must not be empty" if list.empty?
        # respond_to? rather than is_a?(Hash) so ActionController::Parameters keeps working.
        raise ValidationError, "each record must be a Hash" unless list.all? { |r| r.respond_to?(:transform_keys) }

        list.map { |r| r.transform_keys(&:to_s) }
      end

      def validate!(records)
        prefixes = records.size > 1 ? records.each_index.map { |i| "[#{i}]." } : [""]
        pairs = records.zip(prefixes)
        missing = pairs.flat_map { |r, pre| missing_fields(r, pre) }
        invalid = pairs.flat_map { |r, pre| invalid_formats(r, pre) }
        return if missing.empty? && invalid.empty?

        raise ValidationError, validation_message(missing, invalid)
      end

      def missing_fields(record, prefix)
        self::REQUIRED_FIELDS.reject { |f| present?(record[f]) }.map { |f| "#{prefix}#{f}" }
      end

      # The offending value stays out of the message, matching the PII rule on errors.
      def invalid_formats(record, prefix)
        FIELD_FORMATS.filter_map do |field, format|
          value = record[field]
          "#{prefix}#{field} (expected #{format.gsub(/%[YmdHMS]/, FORMAT_LABELS)})" if present?(value) && !valid_format?(value, format)
        end
      end

      # The strftime round-trip rejects what strptime tolerates: "2026-5-20", "20260520 ", "24:00:00".
      def valid_format?(value, format)
        value.is_a?(String) && DateTime.strptime(value, format).strftime(format) == value
      rescue Date::Error
        false
      end

      def validation_message(missing, invalid)
        parts = []
        parts << "missing or empty required fields: #{missing.join(", ")}" if missing.any?
        parts << "invalid format: #{invalid.join(", ")}" if invalid.any?
        parts.join("; ")
      end

      def present?(value)
        !value.to_s.strip.empty?
      end

      def wrap(records, digi_header)
        body = {
          "digi_body" => {
            "std_data" => {
              "parameter" => {
                "request" => {
                  "request_detail" => records
                }
              }
            }
          }
        }
        digi_header ? { "digi_header" => digi_header }.merge(body) : body
      end
    end
  end
end
