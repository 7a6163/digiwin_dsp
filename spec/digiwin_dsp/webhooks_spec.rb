# frozen_string_literal: true

RSpec.describe DigiwinDsp::Webhooks do
  let(:digi_header) do
    {
      "digi_host" => { "prod" => "DSP", "ip" => "", "timestamp" => "20260522120000" },
      "digi_service" => { "prod" => "", "name" => "" }
    }
  end

  def envelope(request_payload)
    {
      "digi_header" => digi_header,
      "digi_body" => { "std_data" => { "parameter" => { "request" => request_payload } } }
    }.to_json
  end

  describe ".parse" do
    it "dispatches product/inventory_update to InventoryUpdate" do
      raw = envelope("prod" => "EC001", "platform_id" => "p1", "sale_page_id" => "sp1", "spec_list" => [])
      event = described_class.parse(raw, action: "product/inventory_update")
      expect(event).to be_a(DigiwinDsp::Webhooks::InventoryUpdate)
    end

    it "dispatches wms/logistics/package/update to LogisticsUpdate" do
      raw = envelope("form_no" => "F1", "tracking_number" => "T1")
      event = described_class.parse(raw, action: "wms/logistics/package/update")
      expect(event).to be_a(DigiwinDsp::Webhooks::LogisticsUpdate)
    end

    it "dispatches invoice/update to InvoiceUpdate" do
      raw = envelope([{ "form_no" => "F1", "invoice_number" => "INV1" }])
      event = described_class.parse(raw, action: "invoice/update")
      expect(event).to be_a(DigiwinDsp::Webhooks::InvoiceUpdate)
    end

    it "raises ParseError for an unknown action" do
      expect { described_class.parse("{}", action: "made/up") }
        .to raise_error(DigiwinDsp::Webhooks::ParseError, /unknown action/i)
    end

    it "raises ParseError for malformed JSON" do
      expect { described_class.parse("not json{", action: "product/inventory_update") }
        .to raise_error(DigiwinDsp::Webhooks::ParseError, /json/i)
    end

    it "raises ParseError for a nil body" do
      expect { described_class.parse(nil, action: "product/inventory_update") }
        .to raise_error(DigiwinDsp::Webhooks::ParseError, /String/)
    end

    it "raises ParseError when the envelope is missing the request payload" do
      raw = { "digi_header" => digi_header, "digi_body" => {} }.to_json
      expect { described_class.parse(raw, action: "product/inventory_update") }
        .to raise_error(DigiwinDsp::Webhooks::ParseError, /request/i)
    end

    it "raises ParseError (not TypeError) when an envelope level is not an object" do
      ['{"digi_body":"x"}', '{"digi_body":[1]}'].each do |raw|
        expect { described_class.parse(raw, action: "product/inventory_update") }
          .to raise_error(DigiwinDsp::Webhooks::ParseError, /request/i)
      end
    end

    it "caps JSON nesting at 50 levels (parser DoS guard)" do
      nested = ->(depth) { ("[" * depth) + ("]" * depth) }
      expect { described_class.parse(nested.call(50), action: "product/inventory_update") }
        .to raise_error(DigiwinDsp::Webhooks::ParseError, /JSON object/)
      # Exact off-by-one boundary varies across json gem versions; assert well past it.
      expect { described_class.parse(nested.call(100), action: "product/inventory_update") }
        .to raise_error(DigiwinDsp::Webhooks::ParseError, /nesting/)
    end

    it "defaults digi_header to an empty hash when the envelope has none" do
      raw = { "digi_body" => { "std_data" => { "parameter" => { "request" => { "form_no" => "F1" } } } } }.to_json
      expect(described_class.parse(raw, action: "wms/logistics/package/update").digi_header).to eq({})
    end

    it "exposes the LogisticsUpdate payload fields" do
      fields = %w[form_no func_name status_date status_time tracking_number distributor_code message]
      payload = fields.to_h { |f| [f, "v-#{f}"] }
      event = described_class.parse(envelope(payload), action: "wms/logistics/package/update")
      expect(fields.map { |f| event.public_send(f) }).to eq(payload.values)
    end

    it "exposes the InventoryUpdate payload fields, defaulting spec_list to []" do
      payload = { "prod" => "EC001", "platform_id" => "p1", "sale_page_id" => "sp1" }
      event = described_class.parse(envelope(payload), action: "product/inventory_update")
      expect([event.prod, event.platform_id, event.sale_page_id, event.spec_list]).to eq(["EC001", "p1", "sp1", []])
    end

    %w[product/inventory_update wms/logistics/package/update].each do |action|
      it "raises ParseError when the #{action} request payload is not an object" do
        expect { described_class.parse(envelope([1, 2]), action: action) }
          .to raise_error(DigiwinDsp::Webhooks::ParseError, /JSON object/i)
      end
    end

    it "raises ParseError when the body parses to a non-Hash JSON value" do
      expect { described_class.parse("[1, 2, 3]", action: "product/inventory_update") }
        .to raise_error(DigiwinDsp::Webhooks::ParseError, /JSON object/i)
    end

    it "keeps parse_json and extract_request private (internal helpers, not public API)" do
      expect { DigiwinDsp::Webhooks::InventoryUpdate.parse_json("{}") }
        .to raise_error(NoMethodError, /private/)
      expect { DigiwinDsp::Webhooks::InventoryUpdate.extract_request({}) }
        .to raise_error(NoMethodError, /private/)
    end
  end

  describe DigiwinDsp::Webhooks::InventoryUpdate do
    let(:payload) do
      {
        "prod" => "EC001", "platform_id" => "p1", "sale_page_id" => "sp1",
        "spec_list" => [
          { "spec_id" => "s1", "product_no" => "A1", "update_mode" => "total", "stock" => 10, "preorder_stock" => 5 }
        ]
      }
    end

    it "exposes prod, platform_id, sale_page_id, spec_list" do
      event = described_class.parse(envelope(payload))
      expect(event.prod).to eq("EC001")
      expect(event.platform_id).to eq("p1")
      expect(event.sale_page_id).to eq("sp1")
      expect(event.spec_list.first).to include("spec_id" => "s1", "stock" => 10)
    end

    it "preserves digi_header and raw envelope" do
      event = described_class.parse(envelope(payload))
      expect(event.digi_header).to include("digi_host", "digi_service")
      expect(event.raw).to be_a(Hash)
    end
  end

  describe DigiwinDsp::Webhooks::LogisticsUpdate do
    let(:payload) do
      {
        "form_no" => "TM231002W00072", "func_name" => "erp.wms.arrived",
        "status_date" => "2023/08/30", "status_time" => "12:00:00",
        "tracking_number" => "1002-6790-1101", "distributor_code" => "HCT", "message" => "已到貨"
      }
    end

    it "exposes the logistics fields" do
      event = described_class.parse(envelope(payload))
      expect(event.form_no).to eq("TM231002W00072")
      expect(event.tracking_number).to eq("1002-6790-1101")
      expect(event.distributor_code).to eq("HCT")
      expect(event.status_date).to eq("2023/08/30")
      expect(event.message).to eq("已到貨")
    end
  end

  describe DigiwinDsp::Webhooks::InvoiceUpdate do
    let(:payload) do
      [
        { "platform_id" => "41142", "form_no" => "F1", "invoice_number" => "INV1", "invoice_status" => "1" },
        { "platform_id" => "41142", "form_no" => "F2", "invoice_number" => "INV2", "invoice_status" => "1" }
      ]
    end

    it "exposes invoices as an Array<Hash>" do
      event = described_class.parse(envelope(payload))
      expect(event.invoices).to be_an(Array)
      expect(event.invoices.size).to eq(2)
      expect(event.invoices.first).to include("invoice_number" => "INV1")
    end

    it "raises ParseError when the request payload is not an array" do
      raw = envelope("not_an_array" => true)
      expect { described_class.parse(raw) }.to raise_error(DigiwinDsp::Webhooks::ParseError, /array/i)
    end
  end
end
