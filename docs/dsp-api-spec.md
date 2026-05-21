# Digiwin DSP — Official Website Module (自有官網模組) API spec digest

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
| `Duplicated:訂單不可重複` ("order cannot be duplicated") | Same `form_no + platform_id` already exists | `DuplicateRequestError` |
| `Processing:取消訂單處理中，不可新增` ("cancellation in flight, cannot add") | Cancel in flight for same order | `ValidationError` (state) |
| `Processing:資料處理中，請稍後再新增` ("data being processed, please retry later") | DSP still processing — retryable | `RateLimitError` |
| `WrongStatus:order_status錯誤...` ("order_status error") | Bad payload | `ValidationError` |
| `系統異常:資料庫存取異常` ("system error: database access exception") | DSP server-side | `ServerError` |

## Implementation impact on the `digiwin_dsp` gem

- `Client#post` cannot rely on HTTP status alone. After parsing the JSON body it must inspect `Status` / `Message` and raise the right `DigiwinDsp::Error` subclass.
- Each resource (`order.rb`, `cancellation.rb`, `invoice.rb`, `return.rb`) wraps the caller's domain hash in the `digi_body.std_data.parameter.request.request_detail[]` envelope via a serializer. `digi_header` is omitted by default — callers can pass one explicitly when their Digiwin integration requires it.
- The auth layer is trivial: attach `DSP-api-key: <key>` header. No token caching needed (so `Authenticator` collapses to a tiny header builder).
