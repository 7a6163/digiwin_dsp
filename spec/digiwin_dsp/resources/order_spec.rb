# frozen_string_literal: true

RSpec.describe DigiwinDsp::Resources::Order do
  subject(:order) { described_class.new }

  let(:base_url) { "https://digiwindsp.digiwin.com/DSP_UAT/api/DSP" }
  let(:endpoint) { "#{base_url}/v1/SalesOrder/add" }
  let(:record) do
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
  let(:json_headers) { { "Content-Type" => "application/json" } }
  let(:success_body) do
    { "Status" => "Success", "Message" => nil, "response_detail" => [record] }.to_json
  end

  before do
    DigiwinDsp.configure do |c|
      c.api_key = "test-key"
      c.base_url = base_url
    end
  end

  describe "#create" do
    it "POSTs to /v1/SalesOrder/add with the serialized envelope" do
      stub_request(:post, endpoint).to_return(status: 200, body: success_body, headers: json_headers)
      order.create(record)
      expected_body = DigiwinDsp::Serializers::SalesOrderSerializer.serialize(record).to_json
      expect(WebMock).to have_requested(:post, endpoint).with(body: expected_body)
    end

    it "returns the response_detail array on Success" do
      stub_request(:post, endpoint).to_return(status: 200, body: success_body, headers: json_headers)
      expect(order.create(record)).to eq([record])
    end

    it "attaches the DSP-api-key header (via Client)" do
      stub_request(:post, endpoint).to_return(status: 200, body: success_body, headers: json_headers)
      order.create(record)
      expect(WebMock).to have_requested(:post, endpoint).with(headers: { "DSP-api-key" => "test-key" })
    end

    it "passes idempotency_key through as X-Idempotency-Key" do
      stub_request(:post, endpoint).to_return(status: 200, body: success_body, headers: json_headers)
      order.create(record, idempotency_key: "order-WEB202605200001")
      expect(WebMock).to have_requested(:post, endpoint).with(headers: { "X-Idempotency-Key" => "order-WEB202605200001" })
    end

    it "includes digi_header in the body when provided" do
      stub_request(:post, endpoint).to_return(status: 200, body: success_body, headers: json_headers)
      header = { "digi_host" => { "prod" => "CUSTOM" } }
      order.create(record, digi_header: header)
      expect(WebMock).to(have_requested(:post, endpoint).with { |req| JSON.parse(req.body)["digi_header"] == header })
    end

    it "raises ValidationError when a required field is missing" do
      bad = record.except("form_no")
      expect { order.create(bad) }.to raise_error(DigiwinDsp::ValidationError, /form_no/)
    end

    it "raises DuplicateRequestError when DSP returns Duplicated:" do
      stub_request(:post, endpoint).to_return(
        status: 200,
        body: { "Status" => "Failure", "Message" => "Duplicated:訂單不可重複" }.to_json,
        headers: json_headers
      )
      expect { order.create(record) }.to raise_error(DigiwinDsp::DuplicateRequestError)
    end
  end

  describe ".create (convenience class method)" do
    it "exposes a class-level shortcut that uses the default client" do
      stub_request(:post, endpoint).to_return(status: 200, body: success_body, headers: json_headers)
      expect(described_class.create(record)).to eq([record])
    end
  end

  it "raises ServerError when DSP returns Success without response_detail" do
    stub_request(:post, endpoint).to_return(status: 200, body: { "Status" => "Success" }.to_json, headers: json_headers)
    expect { order.create(record) }.to raise_error(DigiwinDsp::ServerError, /response_detail/)
  end
end
