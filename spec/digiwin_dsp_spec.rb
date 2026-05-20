# frozen_string_literal: true

RSpec.describe DigiwinDsp do
  it "exposes a VERSION constant" do
    expect(DigiwinDsp::VERSION).to match(/\A\d+\.\d+\.\d+/)
  end
end
