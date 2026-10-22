# frozen_string_literal: true

RSpec.describe DigiwinDsp::Resources::WebhookSubscription do
  subject(:subscription) { described_class.new }

  let(:webhook_base) { "https://digiwindsp.digiwin.com/DSP_UAT/api/webhook" }
  let(:endpoint) { "#{webhook_base}/v1/webhook" }
  let(:callback) { "https://yourshop.example.com/webhooks/dsp" }
  let(:json_headers) { { "Content-Type" => "application/json" } }

  let(:success_body) do
    {
      "srvver" => "1.0",
      "std_data" => {
        "execution" => { "code" => "0", "description" => "" },
        "response" => {
          "platform_id" => "acme_storefront_test",
          "address" => callback,
          "action" => "product/inventory_update"
        }
      }
    }.to_json
  end

  before do
    DigiwinDsp.configure do |c|
      c.api_key      = "test-key"
      c.platform_id  = "acme_storefront_test"
      c.environment  = :sandbox
    end
  end

  it "POSTs to /v1/webhook on the webhook_base_url and returns std_data.response" do
    stub_request(:post, endpoint).to_return(status: 200, body: success_body, headers: json_headers)
    result = subscription.create(action: "product/inventory_update", address: callback)
    expect(result).to include("platform_id" => "acme_storefront_test", "address" => callback, "action" => "product/inventory_update")
  end

  it "wraps the payload in digi_body.std_data.parameter.request with all 4 required fields" do
    expected = {
      "prod" => "OFFICIALWEBSITE", "platform_id" => "acme_storefront_test",
      "action" => "wms/logistics/package/update", "address" => callback
    }
    stub_request(:post, endpoint).to_return(status: 200, body: success_body, headers: json_headers)
    subscription.create(action: "wms/logistics/package/update", address: callback)
    expect(WebMock).to(have_requested(:post, endpoint).with do |req|
      JSON.parse(req.body).dig("digi_body", "std_data", "parameter", "request") == expected
    end)
  end

  it "exposes a class-level shortcut" do
    stub_request(:post, endpoint).to_return(status: 200, body: success_body, headers: json_headers)
    result = described_class.create(action: "product/inventory_update", address: callback)
    expect(result).to include("action")
  end

  it "raises ValidationError when action is not a known DSP action" do
    expect { subscription.create(action: "made/up", address: callback) }
      .to raise_error(DigiwinDsp::ValidationError, /action/)
  end

  it "raises ValidationError when address is missing or empty" do
    expect { subscription.create(action: "product/inventory_update", address: "") }
      .to raise_error(DigiwinDsp::ValidationError, /address/)
  end

  it "allows explicit prod and platform_id overrides" do
    stub_request(:post, endpoint).to_return(status: 200, body: success_body, headers: json_headers)
    subscription.create(action: "invoice/update", address: callback, prod: "QUICKPER", platform_id: "other_store")
    expect(WebMock).to(have_requested(:post, endpoint).with do |req|
      body = JSON.parse(req.body)
      req_payload = body.dig("digi_body", "std_data", "parameter", "request")
      req_payload["prod"] == "QUICKPER" && req_payload["platform_id"] == "other_store"
    end)
  end

  it "raises ValidationError when address exceeds the 500-char DSP limit" do
    long_url = "https://example.com/#{"a" * 500}"
    expect { subscription.create(action: "product/inventory_update", address: long_url) }
      .to raise_error(DigiwinDsp::ValidationError, /address.*500/)
  end

  it "raises ValidationError when address is not https (DSP requires HTTPS callbacks)" do
    expect { subscription.create(action: "product/inventory_update", address: "http://yourshop.example.com/hooks") }
      .to raise_error(DigiwinDsp::ValidationError, /https/i)
  end

  it "derives ACTIONS from Webhooks::ACTION_REGISTRY (subscribable == parseable)" do
    expect(described_class::ACTIONS).to eq(DigiwinDsp::Webhooks::ACTION_REGISTRY.keys)
  end

  describe "non-global configuration (second account)" do
    def store_b
      @store_b ||= DigiwinDsp::Configuration.new.tap do |c|
        c.api_key = "key-b"
        c.platform_id = "store_b"
        c.environment = :sandbox
      end
    end

    def expect_registered_for_store_b
      expect(WebMock).to(have_requested(:post, endpoint).with do |req|
        req.headers["Dsp-Api-Key"] == "key-b" &&
          JSON.parse(req.body).dig("digi_body", "std_data", "parameter", "request", "platform_id") == "store_b"
      end)
    end

    before { stub_request(:post, endpoint).to_return(status: 200, body: success_body, headers: json_headers) }

    it "takes platform_id and api_key from configuration:" do
      described_class.new(configuration: store_b).create(action: "invoice/update", address: callback)
      expect_registered_for_store_b
    end

    it "takes platform_id from a passed client's configuration, not the global one" do
      client = DigiwinDsp::Client.new(configuration: store_b, base_url: store_b.webhook_base_url)
      described_class.new(client).create(action: "invoice/update", address: callback)
      expect_registered_for_store_b
    end
  end

  it "raises ConfigurationError when platform_id is not configured and not passed" do
    DigiwinDsp.reset_configuration!
    DigiwinDsp.configure do |c|
      c.api_key      = "test-key"
      c.environment  = :sandbox
      c.platform_id  = nil
    end
    expect { subscription.create(action: "product/inventory_update", address: callback) }
      .to raise_error(DigiwinDsp::ConfigurationError, /platform_id/)
  end

  it "raises DSP-side error via the existing envelope classifier on execution.code != 0" do
    failure_body = {
      "srvver" => "1.0",
      "std_data" => { "execution" => { "code" => "-1", "description" => "系統異常:資料庫存取異常" } }
    }.to_json
    stub_request(:post, endpoint).to_return(status: 200, body: failure_body, headers: json_headers)
    expect { subscription.create(action: "product/inventory_update", address: callback) }
      .to raise_error(DigiwinDsp::ServerError)
  end
end
