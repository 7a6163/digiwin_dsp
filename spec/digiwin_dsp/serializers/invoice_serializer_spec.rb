# frozen_string_literal: true

RSpec.describe DigiwinDsp::Serializers::InvoiceSerializer do
  let(:valid_record) do
    {
      "platform_id" => "acme_storefront_test",
      "create_datetime" => "2026-05-20 12:00:00",
      "site_no" => "acme_storefront_test",
      "form_no" => "WEB202605200001",
      "invoice_no" => "INV20260520001",
      "invoice_date" => "20260520",
      "invoice_time" => "123000",
      "invoice_status" => "1",
      "invoice_type" => "7",
      "random_code" => "1234",
      "order_status" => "3"
    }
  end

  it "exposes the 11 required invoice fields in spec order" do
    expect(described_class::REQUIRED_FIELDS).to eq(%w[platform_id create_datetime site_no form_no invoice_no invoice_date invoice_time invoice_status invoice_type random_code order_status])
  end

  it "wraps a single record into the digi_body envelope" do
    result = described_class.serialize(valid_record)
    expect(result.dig("digi_body", "std_data", "parameter", "request", "request_detail")).to eq([valid_record])
  end

  it "raises ValidationError when invoice_no is missing" do
    expect { described_class.serialize(valid_record.except("invoice_no")) }
      .to raise_error(DigiwinDsp::ValidationError, /invoice_no/)
  end
end
