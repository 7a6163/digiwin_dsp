# frozen_string_literal: true

module DigiwinDsp
  module Serializers
    # Mix into a serializer module via `extend Base`. The hosting module must
    # define a REQUIRED_FIELDS constant (array of string field names).
    module Base
      def serialize(records, digi_header: nil)
        normalized = normalize(records)
        validate!(normalized)
        wrap(normalized, digi_header)
      end

      private

      def normalize(records)
        list = records.is_a?(Array) ? records : [records]
        list.map { |r| r.transform_keys(&:to_s) }
      end

      def validate!(records)
        problems = records.each_with_index.flat_map { |record, index| missing_fields(record, index, records.size) }
        return if problems.empty?

        raise ValidationError, "missing or empty required fields: #{problems.join(", ")}"
      end

      def missing_fields(record, index, total)
        missing = self::REQUIRED_FIELDS.reject { |f| present?(record[f]) }
        return [] if missing.empty?

        prefix = total > 1 ? "[#{index}]." : ""
        missing.map { |f| "#{prefix}#{f}" }
      end

      def present?(value)
        !value.nil? && !value.to_s.strip.empty?
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
