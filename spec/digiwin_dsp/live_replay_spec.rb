# frozen_string_literal: true

# VCR-replay coverage: verifies the gem parses REAL DSP UAT responses
# correctly (not the synthetic WebMock stubs from the other specs).
#
# Cassettes live under spec/fixtures/cassettes/ with credentials stripped
# (see spec/support/vcr.rb for filter config). Re-record by running:
#
#   RECORD_CASSETTES=1 DIGIWIN_DSP_API_KEY=... DIGIWIN_DSP_PLATFORM_ID=... \
#     bundle exec rspec spec/digiwin_dsp/live_replay_spec.rb
#
# Note: re-recording requires DSP UAT to be reachable and the form_no
# values below to be available (DSP dedupes on form_no + platform_id —
# bump UNIQUE_ID in the constant below if re-record returns
# DuplicateRequestError).

# rubocop:disable RSpec/MultipleMemoizedHelpers, RSpec/DescribeClass
RSpec.describe "DigiwinDsp resources — VCR replay against real UAT" do
  let(:unique_id) { "CASSETTE-002" }
  let(:platform) { ENV.fetch("DIGIWIN_DSP_PLATFORM_ID", "gelovery_web_test") }
  let(:order_form_no) { "#{unique_id}-ORDER" }
  let(:return_form_no) { "#{unique_id}-RETURN" }
  let(:order_record) do
    {
      "platform_id" => platform, "create_datetime" => "2026-05-22 12:00:00",
      "site_no" => platform, "form_no" => order_form_no, "order_date" => "20260522",
      "buyer_name" => "CassetteBuyer", "receiver_name" => "CassetteReceiver",
      "pay_type" => "9104", "shipping_type" => "9102", "tax_type" => "1",
      "sno" => "1", "form_subno" => "1", "product_no" => "CASSETTE-001",
      "product_name" => "CassetteProduct", "unit" => "EA",
      "qty" => "1", "free_qty" => "0", "price" => "100", "subtotal" => "100",
      "payment" => "100", "order_status" => "3", "last_record" => "Y"
    }
  end
  let(:cancel_record) do
    order_record.slice(
      "platform_id", "create_datetime", "site_no", "form_no", "order_date",
      "sno", "product_no"
    ).merge("order_status" => "2")
  end
  let(:invoice_record) do
    {
      "platform_id" => platform, "create_datetime" => "2026-05-22 12:00:00",
      "site_no" => platform, "form_no" => order_form_no,
      "invoice_no" => "#{unique_id}-INV", "invoice_date" => "20260522",
      "invoice_time" => "120000", "invoice_status" => "1",
      "invoice_type" => "7", "random_code" => "1234", "order_status" => "5"
    }
  end
  let(:return_record) do
    {
      "platform_id" => platform, "create_datetime" => "2026-05-22 12:00:00",
      "site_no" => platform, "form_no" => return_form_no, "form_subno" => "1",
      "original_form_no" => order_form_no, "tax_type" => "1",
      "sno" => "1", "product_no" => "CASSETTE-001",
      "qty" => "1", "free_qty" => "0", "price" => "100",
      "subtotal" => "100", "payment" => "100", "order_status" => "7",
      "returner_name" => "CassetteReturner", "returner_address" => "TestAddr",
      "returner_phone" => "0900000000", "returner_zip_code" => "10055"
    }
  end

  before do
    DigiwinDsp.configure do |c|
      c.api_key       = ENV.fetch("DIGIWIN_DSP_API_KEY", "replay-placeholder-key")
      c.platform_id   = platform
      c.environment   = :sandbox
      c.allowed_hosts = ["digiwindsp.digiwin.com"]
    end
  end

  it "Resources::Order.create parses a real /v1/SalesOrder/add response", vcr: { cassette_name: "order_create" } do
    response = DigiwinDsp::Resources::Order.create(order_record)
    expect(response).to be_an(Array)
    expect(response.first).to include("form_no", "platform_id", "order_status")
  end

  it "Resources::Cancellation.create parses a real /v1/SalesOrder/cancel response", vcr: { cassette_name: "cancellation_create" } do
    response = DigiwinDsp::Resources::Cancellation.create(cancel_record)
    expect(response).to be_an(Array)
    expect(response.first).to include("form_no", "order_status")
  end

  it "Resources::Invoice.create parses a real /v1/SalesOrder/invoice response", vcr: { cassette_name: "invoice_create" } do
    response = DigiwinDsp::Resources::Invoice.create(invoice_record)
    expect(response).to be_an(Array)
    expect(response.first).to include("form_no", "invoice_no")
  end

  it "Resources::Return.create parses a real /v1/SalesOrder/return response", vcr: { cassette_name: "return_create" } do
    response = DigiwinDsp::Resources::Return.create(return_record)
    expect(response).to be_an(Array)
    expect(response.first).to include("form_no", "original_form_no", "order_status")
  end
end
# rubocop:enable RSpec/MultipleMemoizedHelpers, RSpec/DescribeClass
