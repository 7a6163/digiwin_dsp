# frozen_string_literal: true

RSpec.describe DigiwinDsp::Authenticator do
  subject(:authenticator) { described_class.new(config) }

  let(:config) do
    DigiwinDsp.configure { |c| c.api_key = "test-key" }
    DigiwinDsp.configuration
  end

  describe "#auth_headers" do
    it "returns the DSP-api-key header carrying the configured api_key" do
      expect(authenticator.auth_headers).to eq("DSP-api-key" => "test-key")
    end
  end
end
