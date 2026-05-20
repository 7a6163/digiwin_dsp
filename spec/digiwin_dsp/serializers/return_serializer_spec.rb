# frozen_string_literal: true

RSpec.describe DigiwinDsp::Serializers::ReturnSerializer do
  let(:valid_record) do
    {
      "platform_id" => "acme_storefront_test",
      "create_datetime" => "2026-05-20 12:00:00",
      "site_no" => "acme_storefront_test",
      "form_no" => "RET202605200001",
      "form_subno" => "1",
      "original_form_no" => "WEB202605200001",
      "tax_type" => "1",
      "sno" => "1",
      "product_no" => "P-001",
      "qty" => "1",
      "free_qty" => "0",
      "price" => "100",
      "subtotal" => "100",
      "payment" => "100",
      "order_status" => "5",
      "returner_name" => "王小明",
      "returner_address" => "新北市",
      "returner_phone" => "0900000000",
      "returner_zip_code" => "10055"
    }
  end

  it "exposes the 19 required return fields" do
    expect(described_class::REQUIRED_FIELDS).to include("original_form_no", "returner_name", "returner_zip_code")
    expect(described_class::REQUIRED_FIELDS.size).to eq(19)
  end

  it "wraps a single record into the digi_body envelope" do
    result = described_class.serialize(valid_record)
    expect(result.dig("digi_body", "std_data", "parameter", "request", "request_detail")).to eq([valid_record])
  end

  it "raises ValidationError when original_form_no is missing" do
    expect { described_class.serialize(valid_record.except("original_form_no")) }
      .to raise_error(DigiwinDsp::ValidationError, /original_form_no/)
  end
end
