# Digiwin DSP — 自有官網模組 API 規格摘要

Source of truth: the four OpenAPI 3.1 YAML files under `docs/dsp-specs/`. This doc is a digest for fast reference; if it conflicts with the YAML, the YAML wins.

## Servers

| 環境 | Base URL |
|---|---|
| 測試區 (UAT) | `https://digiwindsp.digiwin.com/DSP_UAT/api/DSP` |
| 正式區 | `https://digiwindsp.digiwin.com/DSP/api/DSP` |

## Authentication

All four endpoints use the same `apiKey` scheme:

```
DSP-api-key: <key issued by Digiwin>
```

`Authorization` header is **not** used.

## Endpoints

| Operation | Method | Path | OpenAPI file |
|---|---|---|---|
| 新增訂單 (Create Order) | POST | `/v1/SalesOrder/add` | `DSPOOFFICIAL001.yaml` |
| 取消訂單 (Cancel Order) | POST | `/v1/SalesOrder/cancel` | `DSPOOFFICIAL002.yaml` |
| 發票更新 (Invoice Update) | POST | `/v1/SalesOrder/invoice` | `DSPOOFFICIAL004.yaml` |
| 退貨 (Return) | POST | `/v1/SalesOrder/return` | `DSPOOFFICIAL005.yaml` |

All four use `Content-Type: application/json`.

## Request envelope

```jsonc
{
  "digi_header": {
    "digi_host": {
      "prod": "<呼叫方代碼>",
      "ip": "<呼叫方 IP>",
      "timestamp": "<呼叫方時間戳記>"
    },
    "digi_service": {
      "prod": "<服務方代碼>",
      "name": "<服務代碼>"
    }
  },
  "digi_body": {
    "std_data": {
      "parameter": {
        "request": {
          "request_detail": [
            { /* 平台/訂單欄位，見各 YAML */ }
          ]
        }
      }
    }
  }
}
```

The serializer's job is to map the caller's domain object onto `request_detail[]` and synthesize the `digi_header`.

## Response envelope (all four endpoints)

**Always returns HTTP 200**, even on application-level failure. The real status lives in the body:

```jsonc
{
  "Status": "Success",         // or "Failure"
  "Message": null,             // or a failure string (see table below)
  "response_detail": [ /* on Success: echo back the request_detail */ ]
}
```

Known failure `Message` patterns (from `DSPOOFFICIAL001.yaml`, lines ~543–557):

| Message prefix | Meaning | Should map to |
|---|---|---|
| `Duplicated:訂單不可重複` | Same `form_no + platform_id` already exists | `DuplicateRequestError` |
| `Processing:取消訂單處理中，不可新增` | Cancel in flight for same order | `ValidationError` (state) |
| `Processing:資料處理中，請稍後再新增` | DSP still processing — retryable | `RateLimitError` |
| `WrongStatus:order_status錯誤...` | Bad payload | `ValidationError` |
| `系統異常:資料庫存取異常` | DSP server-side | `ServerError` |

## Implementation impact on `digiwin_dsp` gem

- `Client#post` cannot rely on HTTP status alone. After parsing the JSON body it must inspect `Status` / `Message` and raise the right `DigiwinDsp::Error` subclass.
- Each resource (`order.rb`, `cancellation.rb`, `invoice.rb`, `return.rb`) wraps the caller's domain hash in the `digi_header` + `digi_body.std_data.parameter.request.request_detail[]` envelope via a serializer.
- The auth layer is trivial: attach `DSP-api-key: <key>` header. No token caching needed (so `Authenticator` collapses to a tiny header builder).
