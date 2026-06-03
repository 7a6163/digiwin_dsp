# Digiwin DSP — Self-hosted Website Module (自有官網模組) API spec digest

Source of truth: the four OpenAPI 3.1 YAML files under `docs/dsp-specs/`. This doc is a digest for fast reference; if it conflicts with the YAML, the YAML wins.

## Servers

| Environment | Base URL |
|---|---|
| UAT (sandbox) | `https://digiwindsp.digiwin.com/DSP_UAT/api/DSP` |
| Production | `https://digiwindsp.digiwin.com/DSP/api/DSP` |

## Authentication

All four endpoints use the same `apiKey` scheme:

```
DSP-api-key: <key issued by Digiwin>
```

`Authorization` header is **not** used.

## Endpoints

| Operation | Method | Path | OpenAPI file |
|---|---|---|---|
| Create order | POST | `/v1/SalesOrder/add` | `DSPOOFFICIAL001.yaml` |
| Cancel order | POST | `/v1/SalesOrder/cancel` | `DSPOOFFICIAL002.yaml` |
| Invoice update | POST | `/v1/SalesOrder/invoice` | `DSPOOFFICIAL004.yaml` |
| Return | POST | `/v1/SalesOrder/return` | `DSPOOFFICIAL005.yaml` |

All four use `Content-Type: application/json`.

## `order_status` enum

Each endpoint expects a specific `request_detail.order_status` value. DSP rejects any other value with `WrongStatus:order_status錯誤，請固定給N(...)`. Live-verified 2026-05-21 against UAT — the OpenAPI examples are inconsistent and don't document this constraint.

| Value | Meaning | Used by |
|---|---|---|
| `"2"` | 取消訂單 (cancel order) | `Resources::Cancellation` |
| `"3"` | 新增訂單 (new order) | `Resources::Order` |
| `"5"` | 發票更新 (invoice update) | `Resources::Invoice` |
| `"7"` | 退貨訂單 (return order) | `Resources::Return` |

## `pay_type` enum

Payment method codes accepted by `request_detail.pay_type` on `Resources::Order`. Source: `docs/dsp-specs/DSPOOFFICIAL001.yaml` lines 163–179. Field is `maxLength: 30`; the spec's example is `"9104"`. The gem does **not** validate this client-side — bad codes are caught by DSP and surface as `WrongStatus:` → `ValidationError`.

| Value | Meaning |
|---|---|
| `"9100"` | 其他收款方式 (other) |
| `"9101"` | 街口支付 (JKO Pay) |
| `"9102"` | 超商取貨付款 (convenience-store COD) |
| `"9103"` | Google Pay |
| `"9104"` | 信用卡一次付款 (credit card, one-time) |
| `"9105"` | 貨到付款 (cash on delivery) |
| `"9106"` | AFTEE 先享後付 (buy-now-pay-later) |
| `"9107"` | Apple Pay |
| `"9108"` | ATM 付款 (ATM transfer) |
| `"9109"` | 信用卡分期付款 (credit card, installment) |
| `"9110"` | 悠遊付 (EasyWallet) |
| `"9111"` | LINE Pay |
| `"9112"` | PayPal Express |
| `"9113"` | Free Checkout 免費結帳 |
| `"9114"` | 超商代碼繳費 (convenience-store payment code) |

## `shipping_type` enum

Delivery / fulfillment method codes accepted by `request_detail.shipping_type` on `Resources::Order`. Source: `docs/dsp-specs/DSPOOFFICIAL001.yaml` lines 186–200. Field is `maxLength: 30`; the spec's example is `"9102"`.

| Value | Meaning |
|---|---|
| `"9100"` | 其他取貨方式 (other) |
| `"9101"` | 海外宅配 (international delivery) |
| `"9102"` | 宅配貨到付款 (home delivery, COD) |
| `"9103"` | 付款後門市自取 (paid; pickup at store) |
| `"9104"` | 宅配(含離島宅配)已付款只取貨 (home delivery incl. outlying islands, paid; deliver only) |
| `"9105"` | 付款後超商取貨 (paid; convenience-store pickup) |
| `"9106"` | 超商取貨付款 (convenience-store pickup + COD) |
| `"9107"` | 宅配(含離島宅配)貨到付現 (home delivery incl. outlying islands, cash on delivery) |
| `"9108"` | 宅配(含離島宅配)貨到刷卡 (home delivery incl. outlying islands, credit-card on delivery) |

## `invoice_status` enum

Invoice lifecycle state accepted by `request_detail.invoice_status` on `Resources::Invoice`. Source: `docs/dsp-specs/DSPOOFFICIAL004.yaml` lines 110–122. Field is `maxLength: 1`; the spec's example is `"1"`.

| Value | Meaning |
|---|---|
| `"1"` | 開立 (issued) |
| `"2"` | 作廢 (voided) |
| `"3"` | 折讓 (allowance / partial credit) |
| `"4"` | 註銷 (cancelled) |
| `"5"` | 折讓作廢 (allowance voided) |

## `invoice_type` enum

Invoice format accepted by `request_detail.invoice_type` on `Resources::Invoice`. Source: `docs/dsp-specs/DSPOOFFICIAL004.yaml` lines 123–140. Field is `maxLength: 1`; the spec's example is `"7"` (electronic invoice — the modern default in Taiwan).

| Value | Meaning |
|---|---|
| `"1"` | 二聯式 (two-copy invoice) |
| `"2"` | 三聯式 (three-copy invoice) |
| `"3"` | 二聯式收銀機發票 (two-copy register invoice) |
| `"4"` | 三聯式收銀機發票 (three-copy register invoice) |
| `"5"` | 電子計算機發票 (computer-printed invoice) |
| `"6"` | 免用統一發票 (exempt) |
| `"7"` | 電子發票 (e-invoice — most common today) |
| `"A"` | 增值稅專用發票 (China VAT special invoice) |
| `"B"` | 普通發票 (China general invoice) |
| `"C"` | 免用發票 (China exempt) |

## Request envelope

```jsonc
{
  // digi_header is OPTIONAL. The gem omits it by default; pass it only for
  // custom Digiwin integrations that require caller-identity fields.
  "digi_header": {
    "digi_host": {
      "prod": "<caller code>",
      "ip": "<caller IP>",
      "timestamp": "<caller timestamp>"
    },
    "digi_service": {
      "prod": "<service code>",
      "name": "<service operation name>"
    }
  },
  "digi_body": {
    "std_data": {
      "parameter": {
        "request": {
          "request_detail": [
            { /* platform/order fields — see each YAML for the schema */ }
          ]
        }
      }
    }
  }
}
```

The serializer's job is to map the caller's domain object onto `request_detail[]` and (optionally) pass through a caller-supplied `digi_header`.

## Response envelope (all four endpoints)

**Always returns HTTP 200**, even on application-level failure. The real status lives in the body:

```jsonc
{
  "Status": "Success",         // or "Failure"
  "Message": null,             // or a failure string (see table below)
  "response_detail": [ /* on Success: echo back the request_detail */ ]
}
```

Known failure `Message` patterns (from `DSPOOFFICIAL001.yaml`, lines ~543–557). The Chinese strings below are verbatim DSP responses — they are matched exactly by the regex map in `lib/digiwin_dsp/client.rb`:

| Message prefix | Meaning | Should map to |
|---|---|---|
| `DSP 序號驗證失敗` ("DSP key validation failed") | Invalid / missing `DSP-api-key` (auth via envelope, not HTTP 401) | `AuthenticationError` |
| `Duplicated:訂單不可重複` ("order cannot be duplicated") | Same `form_no + platform_id` already exists | `DuplicateRequestError` |
| `Processing:取消訂單處理中，不可新增` ("cancellation in flight, cannot add") | Cancel in flight for same order | `ValidationError` (state) |
| `Processing:資料處理中，請稍後再新增` ("data being processed, please retry later") | DSP still processing — retryable | `RateLimitError` |
| `WrongStatus:order_status錯誤...` ("order_status error") | Bad payload | `ValidationError` |
| `系統異常:資料庫存取異常` ("system error: database access exception") | DSP server-side | `ServerError` |

> ⚠️ Live DSP often prepends the offending `form_no` to `Message` (e.g.
> `ORDER-123:Duplicated:訂單不可重複`). Patterns are substring-matched, not
> anchored, so the prefix doesn't break classification.

## Implementation impact on the `digiwin_dsp` gem

- `Client#post` cannot rely on HTTP status alone. After parsing the JSON body it must inspect `Status` / `Message` and raise the right `DigiwinDsp::Error` subclass.
- Each resource (`order.rb`, `cancellation.rb`, `invoice.rb`, `return.rb`) wraps the caller's domain hash in the `digi_body.std_data.parameter.request.request_detail[]` envelope via a serializer. `digi_header` is omitted by default — callers can pass one explicitly when their Digiwin integration requires it.
- The auth layer is trivial: attach `DSP-api-key: <key>` header. No token caching needed (so `Authenticator` collapses to a tiny header builder).
