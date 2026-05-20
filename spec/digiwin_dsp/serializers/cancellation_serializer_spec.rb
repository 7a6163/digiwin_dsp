# frozen_string_literal: true

RSpec.describe DigiwinDsp::Serializers::CancellationSerializer do
  let(:valid_record) do
    {
      "platform_id" => "acme_storefront_test",
      "create_datetime" => "2026-05-20 12:00:00",
      "site_no" => "acme_storefront_test",
      "form_no" => "WEB202605200001",
      "order_date" => "20260520",
      "sno" => "1",
      "product_no" => "P-001",
      "order_status" => "4"
    }
  end

  it "exposes the 8 required cancel fields in spec order" do
    expect(described_class::REQUIRED_FIELDS).to eq(%w[platform_id create_datetime site_no form_no order_date sno product_no order_status])
  end

  it "wraps a single record into the digi_body envelope" do
    result = described_class.serialize(valid_record)
    expect(result.dig("digi_body", "std_data", "parameter", "request", "request_detail")).to eq([valid_record])
  end

  it "raises ValidationError when form_no is missing" do
    expect { described_class.serialize(valid_record.except("form_no")) }
      .to raise_error(DigiwinDsp::ValidationError, /form_no/)
  end
end
