# frozen_string_literal: true

module DigiwinDsp
  # DSP wire-format code tables as Ruby constants, so callers write
  # `Enums::PayType::CREDIT_CARD` instead of a bare "9104".
  #
  # Source of truth: docs/dsp-specs/*.yaml (see docs/dsp-api-spec.md for the
  # readable digest). The gem deliberately does NOT validate these values
  # client-side — DSP rejects unknown codes with `WrongStatus:` →
  # `ValidationError`. The `ALL` arrays exist for caller-side checks
  # (e.g. dropdowns, model validations) if you want them.
  module Enums
    # request_detail.order_status — fixed per endpoint (live-verified).
    module OrderStatus
      CANCEL    = "2"  # Resources::Cancellation
      NEW_ORDER = "3"  # Resources::Order
      INVOICE   = "5"  # Resources::Invoice
      RETURN    = "7"  # Resources::Return

      ALL = [CANCEL, NEW_ORDER, INVOICE, RETURN].freeze
    end

    # request_detail.pay_type on Resources::Order (DSPOOFFICIAL001:163-195).
    module PayType
      OTHER                   = "9100" # 其他收款方式
      JKO_PAY                 = "9101" # 街口支付
      CVS_COD                 = "9102" # 超商取貨付款
      GOOGLE_PAY              = "9103"
      CREDIT_CARD             = "9104" # 信用卡一次付款
      CASH_ON_DELIVERY        = "9105" # 貨到付款
      AFTEE                   = "9106" # AFTEE 先享後付
      APPLE_PAY               = "9107"
      ATM                     = "9108" # ATM 付款
      CREDIT_CARD_INSTALLMENT = "9109" # 信用卡分期付款
      EASY_WALLET             = "9110" # 悠遊付 (EasyWallet app — distinct from 9118 悠遊卡)
      LINE_PAY                = "9111"
      PAYPAL_EXPRESS          = "9112"
      FREE_CHECKOUT           = "9113" # 免費結帳
      CVS_PAYMENT_CODE        = "9114" # 超商代碼繳費
      POS_CHECKOUT            = "9115" # POS結帳
      ZINGALA                 = "9116" # Zingala 零卡分期付款
      CASH                    = "9117" # 現金
      EASYCARD                = "9118" # 悠遊卡 (physical EasyCard)
      IPASS                   = "9119" # 一卡通
      ICASH_CARD              = "9120" # 愛金卡
      TAIWAN_PAY              = "9121" # 台灣 Pay
      PI_WALLET               = "9122" # Pi 錢包
      OPAY                    = "9123" # 歐付寶
      WECHAT_PAY              = "9124" # 微信
      PX_PAY                  = "9125" # 全支付
      ICASH_PAY               = "9126" # iCashPay
      PLUS_PAY                = "9127" # 全盈支付
      ALIPAY                  = "9128" # 支付寶
      TAISHIN_PAY             = "9129" # 台新 Pay
      COD_CREDIT_CARD         = "9130" # 貨到信用卡一次付款

      ALL = [OTHER, JKO_PAY, CVS_COD, GOOGLE_PAY, CREDIT_CARD, CASH_ON_DELIVERY,
             AFTEE, APPLE_PAY, ATM, CREDIT_CARD_INSTALLMENT, EASY_WALLET,
             LINE_PAY, PAYPAL_EXPRESS, FREE_CHECKOUT, CVS_PAYMENT_CODE,
             POS_CHECKOUT, ZINGALA, CASH, EASYCARD, IPASS, ICASH_CARD,
             TAIWAN_PAY, PI_WALLET, OPAY, WECHAT_PAY, PX_PAY, ICASH_PAY,
             PLUS_PAY, ALIPAY, TAISHIN_PAY, COD_CREDIT_CARD].freeze
    end

    # request_detail.shipping_type on Resources::Order (DSPOOFFICIAL001:186-200).
    module ShippingType
      OTHER              = "9100" # 其他取貨方式
      INTERNATIONAL      = "9101" # 海外宅配
      HOME_DELIVERY_COD  = "9102" # 宅配貨到付款
      STORE_PICKUP_PAID  = "9103" # 付款後門市自取
      HOME_DELIVERY_PAID = "9104" # 宅配(含離島)已付款只取貨
      CVS_PICKUP_PAID    = "9105" # 付款後超商取貨
      CVS_PICKUP_COD     = "9106" # 超商取貨付款
      HOME_DELIVERY_CASH = "9107" # 宅配(含離島)貨到付現
      HOME_DELIVERY_CARD = "9108" # 宅配(含離島)貨到刷卡

      ALL = [OTHER, INTERNATIONAL, HOME_DELIVERY_COD, STORE_PICKUP_PAID,
             HOME_DELIVERY_PAID, CVS_PICKUP_PAID, CVS_PICKUP_COD,
             HOME_DELIVERY_CASH, HOME_DELIVERY_CARD].freeze
    end

    # request_detail.invoice_status on Resources::Invoice (DSPOOFFICIAL004:110-122).
    module InvoiceStatus
      ISSUED           = "1" # 開立
      VOIDED           = "2" # 作廢
      ALLOWANCE        = "3" # 折讓
      CANCELLED        = "4" # 註銷
      ALLOWANCE_VOIDED = "5" # 折讓作廢

      ALL = [ISSUED, VOIDED, ALLOWANCE, CANCELLED, ALLOWANCE_VOIDED].freeze
    end

    # request_detail.invoice_type on Resources::Invoice (DSPOOFFICIAL004:123-140).
    module InvoiceType
      DUPLICATE           = "1" # 二聯式
      TRIPLICATE          = "2" # 三聯式
      DUPLICATE_REGISTER  = "3" # 二聯式收銀機發票
      TRIPLICATE_REGISTER = "4" # 三聯式收銀機發票
      COMPUTER            = "5" # 電子計算機發票
      EXEMPT              = "6" # 免用統一發票
      E_INVOICE           = "7" # 電子發票 — modern default in Taiwan
      CHINA_VAT_SPECIAL   = "A" # 增值稅專用發票
      CHINA_GENERAL       = "B" # 普通發票
      CHINA_EXEMPT        = "C" # 免用發票

      ALL = [DUPLICATE, TRIPLICATE, DUPLICATE_REGISTER, TRIPLICATE_REGISTER,
             COMPUTER, EXEMPT, E_INVOICE, CHINA_VAT_SPECIAL, CHINA_GENERAL,
             CHINA_EXEMPT].freeze
    end

    # E-invoice carrier codes (DSPOOFFICIAL004:167-176). ⚠️ Field name varies:
    # `carrier_type` on Resources::Invoice, `carrier_code` on Resources::Order
    # and the inbound Webhooks::InvoiceUpdate payload.
    module CarrierType
      IPASS          = "1H0001" # 一卡通
      EASYCARD       = "1K0001" # 悠遊卡
      ICASH          = "2G0001"
      MOBILE_BARCODE = "3J0002" # 手機條碼 — most common
      CITIZEN_CERT   = "CQ0001" # 自然人憑證

      ALL = [IPASS, EASYCARD, ICASH, MOBILE_BARCODE, CITIZEN_CERT].freeze
    end

    # request_detail.is_pay on Resources::Invoice (DSPOOFFICIAL004:189-195).
    module IsPay
      UNPAID = "0"
      PAID   = "1"

      ALL = [UNPAID, PAID].freeze
    end

    # spec_list[].update_mode on inbound Webhooks::InventoryUpdate
    # (DSPOOFFICIAL100). "adjust" requires per-customer ERP customization.
    module UpdateMode
      TOTAL  = "total"  # stock is the new total
      ADJUST = "adjust" # stock is a delta (can be negative)

      ALL = [TOTAL, ADJUST].freeze
    end

    # distributor_code on inbound Webhooks::LogisticsUpdate (DSPOOFFICIAL100).
    # Spec lists only these two; handle unknown carriers defensively.
    module DistributorCode
      HCT = "HCT" # 新竹倉儲
      CAT = "CAT" # 統一速達(黑貓)

      ALL = [HCT, CAT].freeze
    end
  end
end
