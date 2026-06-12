# frozen_string_literal: true

RSpec.describe DigiwinDsp::Enums do
  describe "OrderStatus" do
    it "pins the four live-verified endpoint values" do
      expect(described_class::OrderStatus::CANCEL).to eq("2")
      expect(described_class::OrderStatus::NEW_ORDER).to eq("3")
      expect(described_class::OrderStatus::INVOICE).to eq("5")
      expect(described_class::OrderStatus::RETURN).to eq("7")
      expect(described_class::OrderStatus::ALL).to contain_exactly("2", "3", "5", "7")
    end
  end

  describe "PayType" do
    it "pins all 15 codes from DSPOOFFICIAL001" do
      expect(described_class::PayType::CREDIT_CARD).to eq("9104")
      expect(described_class::PayType::CREDIT_CARD_INSTALLMENT).to eq("9109")
      expect(described_class::PayType::LINE_PAY).to eq("9111")
      expect(described_class::PayType::ALL.size).to eq(15)
      expect(described_class::PayType::ALL).to all(match(/\A91\d\d\z/))
    end
  end

  describe "ShippingType" do
    it "pins all 9 codes from DSPOOFFICIAL001" do
      expect(described_class::ShippingType::HOME_DELIVERY_COD).to eq("9102")
      expect(described_class::ShippingType::CVS_PICKUP_COD).to eq("9106")
      expect(described_class::ShippingType::ALL.size).to eq(9)
    end
  end

  describe "InvoiceStatus" do
    it "pins the 5 lifecycle codes from DSPOOFFICIAL004" do
      codes = [
        described_class::InvoiceStatus::ISSUED, described_class::InvoiceStatus::VOIDED,
        described_class::InvoiceStatus::ALLOWANCE, described_class::InvoiceStatus::CANCELLED,
        described_class::InvoiceStatus::ALLOWANCE_VOIDED
      ]
      expect(codes).to eq(%w[1 2 3 4 5])
      expect(described_class::InvoiceStatus::ALL).to eq(codes)
    end
  end

  describe "InvoiceType" do
    it "pins the 10 format codes from DSPOOFFICIAL004" do
      expect(described_class::InvoiceType::E_INVOICE).to eq("7")
      expect(described_class::InvoiceType::DUPLICATE).to eq("1")
      expect(described_class::InvoiceType::TRIPLICATE).to eq("2")
      expect(described_class::InvoiceType::ALL.size).to eq(10)
      expect(described_class::InvoiceType::ALL).to include("A", "B", "C")
    end
  end

  describe "CarrierType" do
    it "pins the 5 e-invoice carrier codes from DSPOOFFICIAL004" do
      expect(described_class::CarrierType::MOBILE_BARCODE).to eq("3J0002")
      expect(described_class::CarrierType::EASYCARD).to eq("1K0001")
      expect(described_class::CarrierType::ALL.size).to eq(5)
    end
  end

  describe "IsPay" do
    it "pins the binary paid/unpaid flag" do
      expect(described_class::IsPay::UNPAID).to eq("0")
      expect(described_class::IsPay::PAID).to eq("1")
    end
  end

  describe "UpdateMode (inbound webhook)" do
    it "pins total/adjust from DSPOOFFICIAL100" do
      expect(described_class::UpdateMode::TOTAL).to eq("total")
      expect(described_class::UpdateMode::ADJUST).to eq("adjust")
    end
  end

  describe "DistributorCode (inbound webhook)" do
    it "pins HCT/CAT from DSPOOFFICIAL100" do
      expect(described_class::DistributorCode::HCT).to eq("HCT")
      expect(described_class::DistributorCode::CAT).to eq("CAT")
    end
  end

  it "freezes every ALL array" do
    arrays = [described_class::OrderStatus::ALL, described_class::PayType::ALL,
              described_class::ShippingType::ALL, described_class::InvoiceStatus::ALL,
              described_class::InvoiceType::ALL, described_class::CarrierType::ALL]
    expect(arrays).to all(be_frozen)
  end
end
