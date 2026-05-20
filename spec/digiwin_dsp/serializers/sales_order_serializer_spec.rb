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
end
