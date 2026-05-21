# frozen_string_literal: true

RSpec.describe DigiwinDsp::Client do
  subject(:client) { described_class.new }

  let(:base_url) { "https://mock.dsp.local" }
  let(:path) { "/api/order/create" }
  let(:url) { "#{base_url}#{path}" }
  let(:payload) { { "order_id" => "O-1", "amount" => 1000 } }
  let(:json_headers) { { "Content-Type" => "application/json" } }

  before do
    DigiwinDsp.configure do |c|
      c.api_key = "test-key"
      c.allowed_hosts = ["mock.dsp.local", "digiwindsp.digiwin.com"]
      c.base_url = base_url
      c.timeout = 1
      c.open_timeout = 1
    end
  end

  describe "#post (success)" do
    it "returns the parsed JSON body" do
      stub_request(:post, url).to_return(status: 200, body: '{"ok":true,"order_id":"O-1"}', headers: json_headers)
      expect(client.post(path, payload)).to eq("ok" => true, "order_id" => "O-1")
    end

    it "sends a JSON Content-Type header" do
      stub_request(:post, url).to_return(status: 200, body: "{}", headers: json_headers)
      client.post(path, payload)
      expect(WebMock).to have_requested(:post, url).with(headers: { "Content-Type" => "application/json" })
    end

    it "sends a User-Agent that identifies the gem" do
      stub_request(:post, url).to_return(status: 200, body: "{}", headers: json_headers)
      client.post(path, payload)
      expect(WebMock).to(have_requested(:post, url).with do |req|
        req.headers["User-Agent"].to_s.include?("digiwin_dsp/#{DigiwinDsp::VERSION}")
      end)
    end

    it "encodes the body as JSON" do
      stub_request(:post, url).to_return(status: 200, body: "{}", headers: json_headers)
      client.post(path, payload)
      expect(WebMock).to have_requested(:post, url).with(body: payload.to_json)
    end

    it "passes idempotency_key as X-Idempotency-Key" do
      stub_request(:post, url).to_return(status: 200, body: "{}", headers: json_headers)
      client.post(path, payload, idempotency_key: "abc-123")
      expect(WebMock).to have_requested(:post, url).with(headers: { "X-Idempotency-Key" => "abc-123" })
    end

    it "merges custom headers" do
      stub_request(:post, url).to_return(status: 200, body: "{}", headers: json_headers)
      client.post(path, payload, headers: { "X-Custom" => "yes" })
      expect(WebMock).to have_requested(:post, url).with(headers: { "X-Custom" => "yes" })
    end
  end

  describe "#post (error mapping)" do
    it "raises ValidationError on 400" do
      stub_request(:post, url).to_return(status: 400, body: '{"error_code":"E001","error_message":"bad payload"}',
                                         headers: json_headers)
      expect { client.post(path, payload) }.to raise_error(DigiwinDsp::ValidationError) do |err|
        expect(err.http_status).to eq(400)
        expect(err.code).to eq("E001")
        expect(err.dsp_message).to eq("bad payload")
      end
    end

    it "raises AuthenticationError on 401" do
      stub_request(:post, url).to_return(status: 401, body: "{}", headers: json_headers)
      expect { client.post(path, payload) }.to raise_error(DigiwinDsp::AuthenticationError) { |e| expect(e.http_status).to eq(401) }
    end

    it "raises AuthenticationError on 403" do
      stub_request(:post, url).to_return(status: 403, body: "{}", headers: json_headers)
      expect { client.post(path, payload) }.to raise_error(DigiwinDsp::AuthenticationError)
    end

    it "raises DuplicateRequestError on 409" do
      stub_request(:post, url).to_return(status: 409, body: '{"error_code":"DUP"}', headers: json_headers)
      expect { client.post(path, payload) }.to raise_error(DigiwinDsp::DuplicateRequestError) { |e| expect(e.http_status).to eq(409) }
    end

    it "raises RateLimitError on persistent 429" do
      stub_request(:post, url).to_return(status: 429, body: "{}", headers: json_headers)
      expect { client.post(path, payload) }.to raise_error(DigiwinDsp::RateLimitError) { |e| expect(e.http_status).to eq(429) }
    end

    it "raises ServerError on persistent 500" do
      stub_request(:post, url).to_return(status: 500, body: "{}", headers: json_headers)
      expect { client.post(path, payload) }.to raise_error(DigiwinDsp::ServerError) { |e| expect(e.http_status).to eq(500) }
    end

    it "raises NetworkError on connection failure" do
      stub_request(:post, url).to_raise(Errno::ECONNREFUSED)
      expect { client.post(path, payload) }.to raise_error(DigiwinDsp::NetworkError)
    end

    it "raises NetworkError on timeout" do
      stub_request(:post, url).to_timeout
      expect { client.post(path, payload) }.to raise_error(DigiwinDsp::NetworkError)
    end
  end

  describe "#post (retry on 429/5xx)" do
    it "retries a 429 then succeeds" do
      stub_request(:post, url)
        .to_return({ status: 429, body: "{}", headers: { "Content-Type" => "application/json" } },
                   { status: 200, body: '{"ok":true}', headers: { "Content-Type" => "application/json" } })
      expect(client.post(path, payload)).to eq("ok" => true)
      expect(WebMock).to have_requested(:post, url).twice
    end

    it "retries a 503 then succeeds" do
      stub_request(:post, url)
        .to_return({ status: 503, body: "{}", headers: { "Content-Type" => "application/json" } },
                   { status: 200, body: '{"ok":true}', headers: { "Content-Type" => "application/json" } })
      expect(client.post(path, payload)).to eq("ok" => true)
      expect(WebMock).to have_requested(:post, url).twice
    end
  end

  describe "configuration validation" do
    it "raises ConfigurationError when api_key is missing" do
      DigiwinDsp.reset_configuration!
      DigiwinDsp.configure do |c|
        c.allowed_hosts = ["mock.dsp.local"]
        c.base_url = base_url
      end
      expect { described_class.new.post(path, payload) }.to raise_error(DigiwinDsp::ConfigurationError, /api_key/)
    end
  end

  describe "edge cases" do
    it "joins paths cleanly when base_url already ends in a slash" do
      DigiwinDsp.reset_configuration!
      DigiwinDsp.configure do |c|
        c.api_key = "test-key"
        c.allowed_hosts = ["mock.dsp.local"]
        c.base_url = "#{base_url}/"
      end
      target = "#{base_url}/api/order/create"
      stub_request(:post, target).to_return(status: 200, body: "{}", headers: json_headers)
      described_class.new.post(path, payload)
      expect(WebMock).to have_requested(:post, target)
    end

    it "raises generic Error with a non-Hash text/plain body on an unmapped status" do
      stub_request(:post, url).to_return(status: 418, body: "server farted", headers: { "Content-Type" => "text/plain" })
      expect { client.post(path, payload) }.to raise_error(DigiwinDsp::Error) do |err|
        expect(err.http_status).to eq(418)
        expect(err.dsp_message).to be_nil
        expect(err).not_to respond_to(:response_body) # PII guard
      end
    end

    it "falls back to body['message'] when body['error_message'] is absent" do
      stub_request(:post, url).to_return(status: 400, body: '{"message":"plain msg"}', headers: json_headers)
      expect { client.post(path, payload) }.to raise_error(DigiwinDsp::ValidationError, /plain msg/)
    end

    it "tolerates a non-Hash response body on a 5xx status" do
      stub_request(:post, url).to_return(status: 500, body: "<html>oops</html>", headers: { "Content-Type" => "text/html" })
      expect { client.post(path, payload) }.to raise_error(DigiwinDsp::ServerError, /HTTP 500/)
    end
  end

  describe "header injection guard (CRLF)" do
    it "rejects idempotency_key containing CRLF" do
      expect { client.post(path, payload, idempotency_key: "abc\r\nX-Injected: evil") }
        .to raise_error(ArgumentError, /header value|CRLF|newline/i)
    end

    it "rejects idempotency_key containing LF only" do
      expect { client.post(path, payload, idempotency_key: "abc\nX-Injected: evil") }
        .to raise_error(ArgumentError)
    end

    it "rejects idempotency_key containing CR only" do
      expect { client.post(path, payload, idempotency_key: "abc\rEvil") }
        .to raise_error(ArgumentError)
    end

    it "rejects a header value containing CRLF" do
      expect { client.post(path, payload, headers: { "X-Foo" => "ok\r\nX-Evil: yes" }) }
        .to raise_error(ArgumentError)
    end

    it "rejects a header name containing CRLF" do
      expect { client.post(path, payload, headers: { "X-Foo\r\nX-Evil" => "yes" }) }
        .to raise_error(ArgumentError)
    end
  end

  describe "authentication" do
    it "attaches DSP-api-key header from configuration" do
      stub_request(:post, url).to_return(status: 200, body: '{"Status":"Success"}', headers: json_headers)
      client.post(path, payload)
      expect(WebMock).to have_requested(:post, url).with(headers: { "DSP-api-key" => "test-key" })
    end
  end

  describe "path joining with a base URL that has a path prefix" do
    let(:base_url) { "https://digiwindsp.digiwin.com/DSP_UAT/api/DSP" }
    let(:path) { "/v1/SalesOrder/add" }

    it "preserves the base path prefix when path starts with a slash" do
      target = "https://digiwindsp.digiwin.com/DSP_UAT/api/DSP/v1/SalesOrder/add"
      stub_request(:post, target).to_return(status: 200, body: '{"Status":"Success"}', headers: json_headers)
      client.post(path, payload)
      expect(WebMock).to have_requested(:post, target)
    end

    it "preserves the base path prefix when path does NOT start with a slash" do
      target = "https://digiwindsp.digiwin.com/DSP_UAT/api/DSP/v1/SalesOrder/add"
      stub_request(:post, target).to_return(status: 200, body: '{"Status":"Success"}', headers: json_headers)
      client.post("v1/SalesOrder/add", payload)
      expect(WebMock).to have_requested(:post, target)
    end
  end

  describe "body envelope (Status/Message)" do
    it "returns the body on Status=Success" do
      stub_request(:post, url).to_return(status: 200, body: '{"Status":"Success","response_detail":[{"form_no":"F1"}]}', headers: json_headers)
      expect(client.post(path, payload)).to include("Status" => "Success")
    end

    it "raises DuplicateRequestError when Message starts with Duplicated:" do
      stub_request(:post, url).to_return(status: 200, body: '{"Status":"Failure","Message":"Duplicated:訂單不可重複"}', headers: json_headers)
      expect { client.post(path, payload) }.to raise_error(DigiwinDsp::DuplicateRequestError) do |e|
        expect(e.dsp_message).to eq("Duplicated:訂單不可重複")
      end
    end

    it "raises RateLimitError when Message starts with Processing:資料處理中" do
      stub_request(:post, url).to_return(status: 200, body: '{"Status":"Failure","Message":"Processing:資料處理中，請稍後再新增"}', headers: json_headers)
      expect { client.post(path, payload) }.to raise_error(DigiwinDsp::RateLimitError)
    end

    it "raises ValidationError when Message starts with Processing:取消訂單處理中" do
      stub_request(:post, url).to_return(status: 200, body: '{"Status":"Failure","Message":"Processing:取消訂單處理中，不可新增"}', headers: json_headers)
      expect { client.post(path, payload) }.to raise_error(DigiwinDsp::ValidationError)
    end

    it "raises ValidationError when Message starts with WrongStatus:" do
      stub_request(:post, url).to_return(status: 200, body: '{"Status":"Failure","Message":"WrongStatus:order_status錯誤"}', headers: json_headers)
      expect { client.post(path, payload) }.to raise_error(DigiwinDsp::ValidationError)
    end

    it "raises ServerError when Message starts with 系統異常:" do
      stub_request(:post, url).to_return(status: 200, body: '{"Status":"Failure","Message":"系統異常:資料庫存取異常"}', headers: json_headers)
      expect { client.post(path, payload) }.to raise_error(DigiwinDsp::ServerError)
    end

    it "raises a generic Error for an unknown failure Message" do
      stub_request(:post, url).to_return(status: 200, body: '{"Status":"Failure","Message":"NeverSeen:something"}', headers: json_headers)
      expect { client.post(path, payload) }.to raise_error(DigiwinDsp::Error)
    end
  end
end
