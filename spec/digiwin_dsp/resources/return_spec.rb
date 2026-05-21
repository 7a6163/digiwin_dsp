# frozen_string_literal: true

RSpec.describe DigiwinDsp::Resources::Return do
  subject(:returns) { described_class.new }

  let(:base_url) { "https://digiwindsp.digiwin.com/DSP_UAT/api/DSP" }
  let(:endpoint) { "#{base_url}/v1/SalesOrder/return" }
  let(:record) do
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
  let(:json_headers) { { "Content-Type" => "application/json" } }
  let(:success_body) { { "Status" => "Success", "response_detail" => [record] }.to_json }

  before do
    DigiwinDsp.configure do |c|
      c.api_key = "test-key"
      c.base_url = base_url
    end
  end

  it "POSTs to /v1/SalesOrder/return and returns response_detail" do
    stub_request(:post, endpoint).to_return(status: 200, body: success_body, headers: json_headers)
    expect(returns.create(record)).to eq([record])
  end

  it "raises ValidationError when original_form_no is missing" do
    expect { returns.create(record.except("original_form_no")) }
      .to raise_error(DigiwinDsp::ValidationError, /original_form_no/)
  end

  it "exposes a class-level shortcut that uses the default client" do
    stub_request(:post, endpoint).to_return(status: 200, body: success_body, headers: json_headers)
    expect(described_class.create(record)).to eq([record])
  end

  it "raises ServerError when DSP returns Success without response_detail" do
    stub_request(:post, endpoint).to_return(status: 200, body: { "Status" => "Success" }.to_json, headers: json_headers)
    expect { returns.create(record) }.to raise_error(DigiwinDsp::ServerError, /response_detail/)
  end
end
