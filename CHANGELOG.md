# Changelog

All notable changes to `digiwin_dsp` are documented here.

The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.1.0] - 2026-05-20

Initial release. Covers the four 自有官網模組 endpoints under `/v1/SalesOrder/*`.

### Added

- `DigiwinDsp.configure` block + per-setting ENV fallback (`DIGIWIN_DSP_API_KEY`, `DIGIWIN_DSP_API_SECRET`, `DIGIWIN_DSP_PLATFORM_ID`, `DIGIWIN_DSP_ENV`, `DIGIWIN_DSP_BASE_URL`)
- `DigiwinDsp::Configuration` — UAT/production base URL resolver, timeout knobs, injectable logger, `#validate!` guard
- `DigiwinDsp::Authenticator` — static `DSP-api-key` header
- `DigiwinDsp::Client` — Faraday 2 connection with:
  - `faraday-retry` for HTTP 429 / 5xx (3 attempts, exponential backoff)
  - Path-prefix-safe URL joining (`/DSP_UAT/api/DSP` + `/v1/SalesOrder/add` → correct full URL)
  - JSON serialization / parsing
  - Status-code → exception mapping
  - **Body-envelope `Status`/`Message` inspection** — DSP returns HTTP 200 even on failure, so the gem classifies `Duplicated:`, `Processing:`, `WrongStatus:`, `系統異常:` patterns into typed exceptions
- Resources, all exposing `#create(records, idempotency_key:, digi_header:)`:
  - `Resources::Order` → `POST /v1/SalesOrder/add`
  - `Resources::Cancellation` → `POST /v1/SalesOrder/cancel`
  - `Resources::Invoice` → `POST /v1/SalesOrder/invoice`
  - `Resources::Return` → `POST /v1/SalesOrder/return`
- Serializers with per-endpoint `REQUIRED_FIELDS` (22 / 8 / 11 / 19) sharing a `Serializers::Base` module that wraps records into the `digi_body.std_data.parameter.request.request_detail[]` envelope
- Exception hierarchy: `Error`, `ConfigurationError`, `AuthenticationError`, `ValidationError`, `RateLimitError`, `ServerError`, `NetworkError`, `DuplicateRequestError` — each carrying `#code`, `#dsp_message`, `#http_status`, `#request_id`, `#response_body`
- `docs/dsp-api-spec.md` summary + `docs/dsp-specs/DSPOOFFICIAL00{1,2,4,5}.yaml` (Digiwin's OpenAPI 3.1 source)
- 127 RSpec examples, WebMock-driven, RuboCop clean

### Design notes

- `digi_header` is **omitted by default**; only passed through when caller provides a custom hash. Standard DSP traffic doesn't need it.
- The gem is **synchronous on purpose**. Callers wrap requests in their own background job runner (e.g. ActiveJob) when needed.
- Idempotency: clients can send `X-Idempotency-Key` via the `idempotency_key:` kwarg. DSP also dedupes server-side by `form_no + platform_id`.

[Unreleased]: https://github.com/7a6163/digiwin_dsp/compare/v0.1.0...HEAD
[0.1.0]: https://github.com/7a6163/digiwin_dsp/releases/tag/v0.1.0
