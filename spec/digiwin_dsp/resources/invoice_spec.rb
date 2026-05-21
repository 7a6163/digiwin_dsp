# frozen_string_literal: true

RSpec.describe DigiwinDsp::Resources::Invoice do
  subject(:invoice) { described_class.new }

  let(:base_url) { "https://digiwindsp.digiwin.com/DSP_UAT/api/DSP" }
  let(:endpoint) { "#{base_url}/v1/SalesOrder/invoice" }
  let(:record) do
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
  let(:json_headers) { { "Content-Type" => "application/json" } }
  let(:success_body) { { "Status" => "Success", "response_detail" => [record] }.to_json }

  before do
    DigiwinDsp.configure do |c|
      c.api_key = "test-key"
      c.base_url = base_url
    end
  end

  it "POSTs to /v1/SalesOrder/invoice and returns response_detail" do
    stub_request(:post, endpoint).to_return(status: 200, body: success_body, headers: json_headers)
    expect(invoice.create(record)).to eq([record])
  end

  it "raises ValidationError when invoice_no is missing" do
    expect { invoice.create(record.except("invoice_no")) }
      .to raise_error(DigiwinDsp::ValidationError, /invoice_no/)
  end

  it "exposes a class-level shortcut that uses the default client" do
    stub_request(:post, endpoint).to_return(status: 200, body: success_body, headers: json_headers)
    expect(described_class.create(record)).to eq([record])
  end

  it "raises ServerError when DSP returns Success without response_detail" do
    stub_request(:post, endpoint).to_return(status: 200, body: { "Status" => "Success" }.to_json, headers: json_headers)
    expect { invoice.create(record) }.to raise_error(DigiwinDsp::ServerError, /response_detail/)
  end
end
