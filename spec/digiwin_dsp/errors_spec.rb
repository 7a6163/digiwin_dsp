# frozen_string_literal: true

RSpec.describe DigiwinDsp::Error do
  describe "#initialize" do
    it "preserves message" do
      expect(described_class.new("boom").message).to eq("boom")
    end

    it "preserves all kwargs" do
      err = described_class.new("boom",
                                code: "E001", dsp_message: "壞掉了",
                                request_id: "req-1", http_status: 500)
      expect([err.code, err.dsp_message, err.request_id, err.http_status])
        .to eq(["E001", "壞掉了", "req-1", 500])
    end

    it "defaults kwargs to nil" do
      err = described_class.new("plain")
      expect([err.code, err.dsp_message, err.request_id, err.http_status])
        .to all(be_nil)
    end

    it "does NOT expose response_body (PII leak guard)" do
      err = described_class.new("boom", code: "E001")
      expect(err).not_to respond_to(:response_body)
      expect(err.instance_variables).not_to include(:@response_body)
    end

    it "rejects a response_body kwarg with ArgumentError" do
      expect { described_class.new("boom", response_body: { "x" => 1 }) }
        .to raise_error(ArgumentError)
    end
  end

  describe "subclass hierarchy" do
    it "puts all named subclasses under DigiwinDsp::Error" do
      %i[ConfigurationError AuthenticationError ValidationError RateLimitError
         ServerError NetworkError DuplicateRequestError].each do |name|
        expect(DigiwinDsp.const_get(name)).to be < described_class
      end
    end

    it "lets subclasses carry kwargs through to the base" do
      err = DigiwinDsp::AuthenticationError.new("nope", code: "AUTH", http_status: 401)
      expect(err).to be_a(described_class)
      expect(err.code).to eq("AUTH")
      expect(err.http_status).to eq(401)
    end
  end
end
