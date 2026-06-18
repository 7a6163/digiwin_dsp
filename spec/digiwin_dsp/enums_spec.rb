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
    it "pins all 31 codes from DSPOOFFICIAL001 (9100-9130)" do
      pt = described_class::PayType
      spot = [pt::CREDIT_CARD, pt::CREDIT_CARD_INSTALLMENT, pt::LINE_PAY,
              pt::IPASS, pt::ALIPAY, pt::COD_CREDIT_CARD]
      expect(spot).to eq(%w[9104 9109 9111 9119 9128 9130])
      expect(pt::ALL.size).to eq(31)
      expect(pt::ALL).to all(match(/\A91[0-3]\d\z/))
    end
  end

  describe "ShippingType" do
    it "pins all 10 codes from DSPOOFFICIAL001 (incl. 9109 rev 5)" do
      expect(described_class::ShippingType::HOME_DELIVERY_COD).to eq("9102")
      expect(described_class::ShippingType::CVS_PICKUP_COD).to eq("9106")
      expect(described_class::ShippingType::FACE_TO_FACE_PICKUP).to eq("9109")
      expect(described_class::ShippingType::ALL.size).to eq(10)
    end
  end

  describe "TaxType" do
    it "pins taxable/tax-free from DSPOOFFICIAL001" do
      expect(described_class::TaxType::TAXABLE).to eq("1")
      expect(described_class::TaxType::TAX_FREE).to eq("2")
      expect(described_class::TaxType::ALL).to eq(%w[1 2])
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
