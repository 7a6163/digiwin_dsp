# frozen_string_literal: true

RSpec.describe DigiwinDsp::Serializers::SalesOrderSerializer do
  let(:valid_record) do
    {
      "platform_id" => "acme_storefront_test",
      "create_datetime" => "2026-05-20 12:00:00",
      "site_no" => "acme_storefront_test",
      "form_no" => "WEB202605200001",
      "order_date" => "20260520",
      "buyer_name" => "王小明",
      "receiver_name" => "王小明",
      "pay_type" => "9104",
      "shipping_type" => "9102",
      "tax_type" => "1",
      "sno" => "1",
      "form_subno" => "1",
      "product_no" => "P-001",
      "product_name" => "測試商品",
      "unit" => "EA",
      "qty" => "1",
      "free_qty" => "0",
      "price" => "100",
      "subtotal" => "100",
      "payment" => "100",
      "order_status" => "3",
      "last_record" => "Y"
    }
  end

  describe ".serialize (single record)" do
    it "puts the record under digi_body.std_data.parameter.request.request_detail" do
      result = described_class.serialize(valid_record)
      expect(result.dig("digi_body", "std_data", "parameter", "request", "request_detail")).to eq([valid_record])
    end

    it "produces an envelope with only the digi_body key by default" do
      expect(described_class.serialize(valid_record).keys).to eq(["digi_body"])
    end
  end

  describe ".serialize (malformed input)" do
    it "rejects an empty array" do
      expect { described_class.serialize([]) }.to raise_error(DigiwinDsp::ValidationError, /empty/)
    end

    it "rejects nil and non-Hash records" do
      [nil, [valid_record, nil], ["x"]].each do |records|
        expect { described_class.serialize(records) }.to raise_error(DigiwinDsp::ValidationError, /Hash/)
      end
    end
  end

  describe ".serialize (array of records)" do
    it "preserves the array order in request_detail" do
      r1 = valid_record.merge("sno" => "1", "last_record" => "N")
      r2 = valid_record.merge("sno" => "2", "last_record" => "Y")
      result = described_class.serialize([r1, r2])
      expect(result.dig("digi_body", "std_data", "parameter", "request", "request_detail")).to eq([r1, r2])
    end
  end

  describe ".serialize with digi_header override" do
    it "includes digi_header at the top level when provided" do
      header = { "digi_host" => { "prod" => "CUSTOM" } }
      result = described_class.serialize(valid_record, digi_header: header)
      expect(result["digi_header"]).to eq(header)
    end

    it "omits digi_header when explicitly nil" do
      expect(described_class.serialize(valid_record, digi_header: nil)).not_to have_key("digi_header")
    end
  end

  describe "validation of required fields" do
    DigiwinDsp::Serializers::SalesOrderSerializer::REQUIRED_FIELDS.each do |field|
      it "raises ValidationError when #{field} is missing" do
        bad = valid_record.dup
        bad.delete(field)
        expect { described_class.serialize(bad) }.to raise_error(DigiwinDsp::ValidationError, /#{field}/)
      end

      it "raises ValidationError when #{field} is an empty string" do
        bad = valid_record.merge(field => "")
        expect { described_class.serialize(bad) }.to raise_error(DigiwinDsp::ValidationError, /#{field}/)
      end
    end

    it "lists every missing field in one error message" do
      bad = valid_record.dup
      bad.delete("form_no")
      bad.delete("qty")
      expect { described_class.serialize(bad) }.to raise_error(DigiwinDsp::ValidationError, /form_no.*qty|qty.*form_no/)
    end

    it "validates each record in an array independently" do
      r1 = valid_record
      r2 = valid_record.merge("sno" => "2", "last_record" => "Y")
      r2.delete("price")
      expect { described_class.serialize([r1, r2]) }.to raise_error(DigiwinDsp::ValidationError, /\[1\].*price/)
    end

    it "accepts symbol keys too" do
      symbol_record = valid_record.transform_keys(&:to_sym)
      expect { described_class.serialize(symbol_record) }.not_to raise_error
    end
  end

  describe "validation of date/time formats" do
    {
      "create_datetime" => ["2026/05/20 12:00:00", "2026-5-20 12:00:00", "2026-05-20"],
      "order_date" => %w[2026-05-20 20260230 2026052],
      "invoice_date" => ["2026/05/20", "20261301"],
      "invoice_time" => ["123000", "25:00:00", "24:00:00", "12:30"],
      "order_expect_shipping_date" => ["2026-05-20"]
    }.each do |field, bad_values|
      bad_values.each do |value|
        it "rejects #{field}=#{value.inspect}" do
          expect { described_class.serialize(valid_record.merge(field => value)) }
            .to raise_error(DigiwinDsp::ValidationError, /invalid format: #{field} \(expected [YHD]/)
        end
      end
    end

    it "accepts well-formed optional date/time fields" do
      ok = valid_record.merge("invoice_date" => "20240229", "invoice_time" => "23:59:59", "order_expect_shipping_date" => "20260601")
      expect { described_class.serialize(ok) }.not_to raise_error
    end

    it "skips blank optional date/time fields" do
      expect { described_class.serialize(valid_record.merge("invoice_time" => "", "invoice_date" => nil)) }.not_to raise_error
    end

    it "rejects non-string values such as Time objects" do
      expect { described_class.serialize(valid_record.merge("create_datetime" => Time.now)) }
        .to raise_error(DigiwinDsp::ValidationError, /create_datetime/)
    end

    it "names the expected format in spec notation" do
      expect { described_class.serialize(valid_record.merge("invoice_time" => "123000", "create_datetime" => "x")) }
        .to raise_error(DigiwinDsp::ValidationError, /create_datetime \(expected YYYY-MM-DD HH:MM:SS\), invoice_time \(expected HH:MM:SS\)/)
    end

    it "keeps the offending value out of the message" do
      expect { described_class.serialize(valid_record.merge("order_date" => "2026-05-20")) }
        .to raise_error(DigiwinDsp::ValidationError) { |e| expect(e.message).not_to include("2026-05-20") }
    end

    it "reports missing and invalid fields together, indexed per record" do
      r2 = valid_record.merge("sno" => "2", "order_date" => "bad").except("price")
      expect { described_class.serialize([valid_record, r2]) }
        .to raise_error(DigiwinDsp::ValidationError, /missing or empty required fields: \[1\]\.price; invalid format: \[1\]\.order_date/)
    end
  end
end
