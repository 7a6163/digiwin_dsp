# Changelog

All notable changes to `digiwin_dsp` are documented here.

The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Docs

- Document the `order_status` enum (`"2"` cancel / `"3"` new / `"5"` invoice / `"7"` return). DSP rejects others with `WrongStatus:order_status錯誤，請固定給N(...)`. All four live-verified against UAT 2026-05-22. The OpenAPI examples don't surface this constraint, so live smoke had to discover each value.

## [0.2.2] - 2026-05-21

### Fixed

- **`Message:"DSP 序號驗證失敗"` now classifies as
  `DigiwinDsp::AuthenticationError`.** Discovered via live UAT smoke
  test: when the `DSP-api-key` header is missing or invalid, DSP
  returns HTTP 200 (not 401/403) with `Status:Failure` and that
  message. Previously fell through to generic `Error`, defeating
  typed-rescue logic.

### Docs

- `docs/dsp-api-spec.md` documents the auth-failure envelope shape +
  the form_no-prefix behavior on `Message`.

## [0.2.1] - 2026-05-21

### Fixed

- **Envelope failure-message regexes now match anywhere in the string**
  (dropped the `\A` anchor). Discovered via live UAT smoke test: DSP
  prepends the offending `form_no` to `Message`, so the actual response
  is e.g. `"ORDER-123:Duplicated:訂單不可重複"` rather than the
  OpenAPI-example shape `"Duplicated:訂單不可重複"`. Previously the
  prefix caused `DuplicateRequestError` / `RateLimitError` /
  `ValidationError` / `ServerError` classifications to fall through to
  generic `DigiwinDsp::Error`, defeating typed-rescue logic in callers.

### Changed

- CI CVE audit switched from the `bundler-audit` Ruby gem to the
  `7a6163/gem-audit-action@v1` GitHub Action (which wraps the
  `gem-audit` Rust binary). Faster, no runtime gem to keep updated, and
  the action handles platform/version selection. Dropped `bundler-audit`
  from the dev/test Gemfile group.
- Rubocop now excludes `scripts/**/*` (operator scripts; not gem source).

## [0.2.0] - 2026-05-21

Security + correctness release. Addresses every HIGH and MEDIUM finding
from the v0.1.x code review. Pre-1.0 SemVer; contains one breaking change.

### BREAKING

- **`DigiwinDsp::Error#response_body` removed.** Storing the full DSP
  response on every exception leaked buyer PII (names, addresses, phone
  numbers) to Sentry/Honeybadger/Rollbar via their default instance-var
  serialization. Structured fields remain: `#code`, `#dsp_message`,
  `#http_status`, `#request_id`. If you need the raw body, capture it in
  your own Faraday middleware before the request reaches this gem.
  **Migration:** delete any `e.response_body` access from rescue blocks.

### Added

- `Configuration#allowed_hosts` (default `["digiwindsp.digiwin.com"]`) —
  SSRF allowlist enforced on `#base_url`. Extend it for proxy/mock setups:
  `c.allowed_hosts += ["dsp-proxy.your-co.internal"]`.
- CRLF (`\r` / `\n`) validation on `idempotency_key` and every entry of
  the `headers:` kwarg in `Client#post`. Raises `ArgumentError` on
  injection attempts (closes a header-smuggling vector that Faraday's
  default adapter doesn't fully catch).
- `bundler-audit` ~> 0.9 in dev/test + a CI step (`bundle-audit check
  --update`) that fails on any known CVE in the locked dependency tree.

### Changed

- `Configuration#base_url` now validates the resolved URL:
  - scheme MUST be `https` (no HTTP downgrade for the `DSP-api-key`)
  - host MUST be in `allowed_hosts` (default: only `digiwindsp.digiwin.com`)
  - malformed URIs raise `ConfigurationError`
- Resources::{Order,Cancellation,Invoice,Return}#create now raise
  `DigiwinDsp::ServerError` when DSP returns `Status:"Success"` without a
  `response_detail` key, instead of returning `nil` (which became a
  silent `NoMethodError` downstream).
- Faraday retry now uses real exponential backoff with jitter
  (`interval: 0.5, backoff_factor: 2, interval_randomness: 0.5`).
  Previously `interval: 0, backoff_factor: 1` fired all three retries
  instantly — actively counterproductive on 429 throttling.
- Faraday `:json` middleware gains `parser_options: { max_nesting: 50 }`
  as a DoS guard against hostile / malformed DSP responses.
- `Resources::*.create` class-method shortcuts now declare typed kwargs
  (`idempotency_key:`, `digi_header:`) so caller typos raise `ArgumentError`
  at call time instead of being swallowed by `**`.
- README configuration table distinguishes runtime-used settings from
  reserved ones; calls out that `platform_id` lives in `request_detail`,
  not auth headers; documents `allowed_hosts` + the proxy-override pattern.

### Removed

- `DigiwinDsp::Authenticator#auth_headers` no longer calls
  `Configuration#validate!`. Validation was redundant (Client#post runs
  it per-request) and silently skipped after construction-time mutation
  due to connection memoization.

## [0.1.1] - 2026-05-21

### Added

- Release workflow (`.github/workflows/release.yml`): tag push (`v*`) triggers RubyGems publish via OIDC Trusted Publishing, runs the full spec suite as a guard, and updates the GitHub Release with the built `.gem` artifact.
- Release workflow also dual-publishes to GitHub Packages (`https://rubygems.pkg.github.com/7a6163`) using the auto-provided `GITHUB_TOKEN` — no extra secret required.

### Changed

- `actions/checkout` bumped v4 → v6 (Node 24 runtime)
- `codecov/codecov-action` bumped v4 → v6 (Node 24 runtime)
- Rubyfast perf hints applied: `ENV["KEY"]` over `ENV.fetch("KEY", nil)` for nil-default lookups, explicit `times` loop over `each_with_index.flat_map` in `Serializers::Base#validate!`
- Disabled rubocop `Style/FetchEnvVar` and `Style/RedundantFetchBlock` (conflict with rubyfast's perf-grounded preferences)

### Fixed

- Pin `parallel < 2.0` in dev deps so the Ruby 3.2 CI row can still resolve rubocop (`parallel 2.x` requires Ruby ≥ 3.3)

## [0.1.0] - 2026-05-21

Initial release. Covers the four Self-hosted Website Module (自有官網模組) endpoints under `/v1/SalesOrder/*`.

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
- 134 RSpec examples, WebMock-driven, 100% line + 100% branch coverage, RuboCop clean

### Tooling

- SimpleCov + simplecov-lcov coverage reporting (line + branch); minimum thresholds 80% line / 70% branch
- GitHub Actions CI workflow (`.github/workflows/ci.yml`): Ruby 3.2 / 3.3 / 3.4 matrix, runs RuboCop + RSpec, uploads `coverage/lcov.info` to Codecov on the 3.3 row
- CI status + Codecov coverage badges in README

### Design notes

- `digi_header` is **omitted by default**; only passed through when caller provides a custom hash. Standard DSP traffic doesn't need it.
- The gem is **synchronous on purpose**. Callers wrap requests in their own background job runner (e.g. ActiveJob) when needed.
- Idempotency: clients can send `X-Idempotency-Key` via the `idempotency_key:` kwarg. DSP also dedupes server-side by `form_no + platform_id`.

[Unreleased]: https://github.com/7a6163/digiwin_dsp/compare/v0.2.2...HEAD
[0.2.2]: https://github.com/7a6163/digiwin_dsp/compare/v0.2.1...v0.2.2
[0.2.1]: https://github.com/7a6163/digiwin_dsp/compare/v0.2.0...v0.2.1
[0.2.0]: https://github.com/7a6163/digiwin_dsp/compare/v0.1.1...v0.2.0
[0.1.1]: https://github.com/7a6163/digiwin_dsp/compare/v0.1.0...v0.1.1
[0.1.0]: https://github.com/7a6163/digiwin_dsp/releases/tag/v0.1.0
