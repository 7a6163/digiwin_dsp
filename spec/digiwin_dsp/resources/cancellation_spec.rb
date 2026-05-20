# frozen_string_literal: true

RSpec.describe DigiwinDsp::Resources::Cancellation do
  subject(:cancellation) { described_class.new }

  let(:base_url) { "https://digiwindsp.digiwin.com/DSP_UAT/api/DSP" }
  let(:endpoint) { "#{base_url}/v1/SalesOrder/cancel" }
  let(:record) do
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
  let(:json_headers) { { "Content-Type" => "application/json" } }
  let(:success_body) { { "Status" => "Success", "response_detail" => [record] }.to_json }

  before do
    DigiwinDsp.configure do |c|
      c.api_key = "test-key"
      c.base_url = base_url
    end
  end

  it "POSTs to /v1/SalesOrder/cancel and returns response_detail" do
    stub_request(:post, endpoint).to_return(status: 200, body: success_body, headers: json_headers)
    expect(cancellation.create(record)).to eq([record])
  end

  it "raises ValidationError when a required field is missing" do
    expect { cancellation.create(record.except("form_no")) }
      .to raise_error(DigiwinDsp::ValidationError, /form_no/)
  end
end
