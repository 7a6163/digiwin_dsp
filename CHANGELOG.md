# Changelog

All notable changes to `digiwin_dsp` are documented here.

The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

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
- 134 RSpec examples, WebMock-driven, 100% line + 100% branch coverage, RuboCop clean

### Tooling

- SimpleCov + simplecov-lcov coverage reporting (line + branch); minimum thresholds 80% line / 70% branch
- GitHub Actions CI workflow (`.github/workflows/ci.yml`): Ruby 3.2 / 3.3 / 3.4 matrix, runs RuboCop + RSpec, uploads `coverage/lcov.info` to Codecov on the 3.3 row
- CI status + Codecov coverage badges in README

### Design notes

- `digi_header` is **omitted by default**; only passed through when caller provides a custom hash. Standard DSP traffic doesn't need it.
- The gem is **synchronous on purpose**. Callers wrap requests in their own background job runner (e.g. ActiveJob) when needed.
- Idempotency: clients can send `X-Idempotency-Key` via the `idempotency_key:` kwarg. DSP also dedupes server-side by `form_no + platform_id`.

[Unreleased]: https://github.com/7a6163/digiwin_dsp/compare/v0.1.1...HEAD
[0.1.1]: https://github.com/7a6163/digiwin_dsp/compare/v0.1.0...v0.1.1
[0.1.0]: https://github.com/7a6163/digiwin_dsp/releases/tag/v0.1.0
