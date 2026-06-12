# digiwin_dsp

[![CI](https://github.com/7a6163/digiwin_dsp/actions/workflows/ci.yml/badge.svg)](https://github.com/7a6163/digiwin_dsp/actions/workflows/ci.yml)
[![codecov](https://codecov.io/gh/7a6163/digiwin_dsp/branch/main/graph/badge.svg)](https://codecov.io/gh/7a6163/digiwin_dsp)
[![Ruby](https://img.shields.io/badge/ruby-%E2%89%A53.2-CC342D)](https://www.ruby-lang.org/)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](./LICENSE.txt)

Ruby client for the Digiwin DSP Self-hosted Website Module (自有官網模組) API. Lets your storefront push orders, cancellations, invoice updates, and returns into the Digiwin ERP through the DSP gateway.

| Operation | Resource | Endpoint |
|---|---|---|
| Create order | `DigiwinDsp::Resources::Order` | `POST /v1/SalesOrder/add` |
| Cancel order | `DigiwinDsp::Resources::Cancellation` | `POST /v1/SalesOrder/cancel` |
| Invoice update | `DigiwinDsp::Resources::Invoice` | `POST /v1/SalesOrder/invoice` |
| Return | `DigiwinDsp::Resources::Return` | `POST /v1/SalesOrder/return` |
| Register webhook | `DigiwinDsp::Resources::WebhookSubscription` | `POST /v1/webhook` (on webhook_base_url) |
| Receive webhook (inbound) | `DigiwinDsp::Webhooks.parse` | — |

See [`docs/dsp-api-spec.md`](./docs/dsp-api-spec.md) (plus `docs/dsp-specs/*.yaml`) for the wire spec.

## Installation

```ruby
# Gemfile
gem "digiwin_dsp"
```

```bash
bundle install
```

Ruby ≥ 3.2 required.

## Configuration

Configure once at boot (e.g. `config/initializers/digiwin_dsp.rb` in Rails):

```ruby
DigiwinDsp.configure do |c|
  c.api_key      = ENV.fetch("DIGIWIN_DSP_API_KEY")
  c.platform_id  = ENV.fetch("DIGIWIN_DSP_PLATFORM_ID")
  c.environment  = :sandbox          # :sandbox (UAT) | :production
  c.logger       = Rails.logger      # any Logger-like object
  c.timeout      = 10                # request timeout (seconds)
  c.open_timeout = 5
end
```

Every setting also falls back to an ENV var:

| Setting | ENV var | Default | Notes |
|---|---|---|---|
| `api_key` | `DIGIWIN_DSP_API_KEY` | _(required)_ | sent as `DSP-api-key` header |
| `api_secret` | `DIGIWIN_DSP_API_SECRET` | `nil` | reserved for future HMAC signing; unused today |
| `platform_id` | `DIGIWIN_DSP_PLATFORM_ID` | `nil` | sent **per-record** in `request_detail.platform_id` (not in auth headers) |
| `environment` | `DIGIWIN_DSP_ENV` | `:sandbox` | `:sandbox` (UAT) or `:production` |
| `base_url` | `DIGIWIN_DSP_BASE_URL` | resolved from `environment` | must be `https://` and have a host in `allowed_hosts` |
| `webhook_base_url` | `DIGIWIN_DSP_WEBHOOK_BASE_URL` | resolved from `environment` | for `WebhookSubscription`; same validation as `base_url` |
| `allowed_hosts` | — | `["digiwindsp.digiwin.com"]` | SSRF allowlist; extend if you proxy DSP through a different domain |
| `timeout` | — | `10` | seconds |
| `open_timeout` | — | `5` | seconds |
| `logger` | — | `Logger.new(IO::NULL)` | any Logger-like object |

Base URLs (resolved from `environment`):

- `:sandbox` → `https://digiwindsp.digiwin.com/DSP_UAT/api/DSP`
- `:production` → `https://digiwindsp.digiwin.com/DSP/api/DSP`

See [`.env.local.example`](./.env.local.example) for a starter env file.

### Custom proxy host

If you front DSP with a corporate proxy or use a mock server, add the host:

```ruby
DigiwinDsp.configure do |c|
  c.allowed_hosts += ["dsp-proxy.your-co.internal"]
  c.base_url = "https://dsp-proxy.your-co.internal/api/DSP"
end
```

Any host not in `allowed_hosts`, or any non-`https://` URL, raises
`DigiwinDsp::ConfigurationError`. This is an SSRF + HTTP-downgrade guard
since `DIGIWIN_DSP_BASE_URL` accepts arbitrary input.

## Usage

Each resource exposes a single `#create(records, idempotency_key:, digi_header:)` method that returns the parsed `response_detail` array on success or raises a typed exception on failure.

### Create an order

```ruby
record = {
  "platform_id"     => "acme_storefront_test",
  "create_datetime" => Time.now.strftime("%Y-%m-%d %H:%M:%S"),
  "site_no"         => "acme_storefront_test",
  "form_no"         => "WEB202605200001",     # storefront order number
  "order_date"      => "20260520",
  "buyer_name"      => "王小明",
  "receiver_name"   => "王小明",
  "pay_type"        => "9104",
  "shipping_type"   => "9102",
  "tax_type"        => "1",
  "sno"             => "1",                   # line index
  "form_subno"      => "1",
  "product_no"      => "P-001",
  "product_name"    => "測試商品",
  "unit"            => "EA",
  "qty"             => "1",
  "free_qty"        => "0",
  "price"           => "100",
  "subtotal"        => "100",
  "payment"         => "100",
  "order_status"    => "3",                   # 3 = new order
  "last_record"     => "Y"                    # "Y" on the final line
}

response_detail = DigiwinDsp::Resources::Order.create(record)
# => [{ "form_no" => "WEB202605200001", ... }]
```

Multi-line orders: pass an array. Each element must carry the order-level fields plus its own line fields. Set `"last_record" => "Y"` on the final element and `"N"` on the rest:

```ruby
records = [
  base_fields.merge("sno" => "1", "product_no" => "P-001", "qty" => "1", "last_record" => "N"),
  base_fields.merge("sno" => "2", "product_no" => "P-002", "qty" => "3", "last_record" => "Y")
]

DigiwinDsp::Resources::Order.create(records)
```

### Cancel, invoice update, return

```ruby
DigiwinDsp::Resources::Cancellation.create(cancel_record)
DigiwinDsp::Resources::Invoice.create(invoice_record)
DigiwinDsp::Resources::Return.create(return_record)
```

Each has its own required-field set (8 / 11 / 19 fields respectively). Inspect `REQUIRED_FIELDS` for the exact list, e.g.:

```ruby
DigiwinDsp::Serializers::CancellationSerializer::REQUIRED_FIELDS
```

### `order_status` enum

Each endpoint requires a specific `order_status` value inside `request_detail`. DSP rejects others with `WrongStatus:order_status錯誤，請固定給N(...)`. The OpenAPI examples don't document this — verified live against UAT 2026-05-21:

| Resource | `order_status` | Meaning |
|---|---|---|
| `Resources::Order` | `"3"` | 新增訂單 (new order) |
| `Resources::Cancellation` | `"2"` | 取消訂單 (cancel order) |
| `Resources::Invoice` | `"5"` | 發票更新 (invoice update) |
| `Resources::Return` | `"7"` | 退貨訂單 (return order) |

### Idempotency

**DSP only dedupes on `form_no + platform_id`.** Use a deterministic `form_no` derived from your domain order ID and DSP will reject duplicates with `Duplicated:訂單不可重複` (mapped to `DuplicateRequestError`).

The `idempotency_key:` kwarg attaches an `X-Idempotency-Key` request header for logging/tracing on your side, but **DSP UAT does not act on it** (live-verified 2026-05-22 with two distinct `form_no` POSTs sharing the same key — both succeeded). Treat the header as a trace ID, not an idempotency guarantee.

```ruby
DigiwinDsp::Resources::Order.create(record, idempotency_key: "order-#{record['form_no']}")
```

### Webhooks (DSP push events)

Two halves — register a callback URL with DSP, then receive ERP-originated events at that URL.

**Register (outbound)** — tell DSP where to push notifications for one of three documented actions:

```ruby
DigiwinDsp::Resources::WebhookSubscription.create(
  action:  "product/inventory_update",         # or "wms/logistics/package/update", "invoice/update"
  address: "https://yourshop.example.com/webhooks/dsp/inventory"
)
# => { "platform_id" => ..., "address" => ..., "action" => ... }
```

`platform_id` falls back to `Configuration#platform_id`; `prod` defaults to `"OFFICIALWEBSITE"`. Each action needs its own subscription call.

**Receive (inbound)** — parse what DSP POSTs to your callback URL:

```ruby
# config/routes.rb
post "/webhooks/dsp/inventory", to: "dsp_webhooks#inventory"

# app/controllers/dsp_webhooks_controller.rb
class DspWebhooksController < ActionController::API
  def inventory
    event = DigiwinDsp::Webhooks::InventoryUpdate.parse(request.raw_post)
    # event.platform_id, event.sale_page_id, event.spec_list[] — see docs/dsp-specs/DSPOOFFICIAL100.yaml
    DspInventoryUpdateJob.perform_later(event.raw)
    head :ok
  rescue DigiwinDsp::Webhooks::ParseError => e
    Rails.logger.error("DSP webhook parse failed: #{e.dsp_message || e.message}")
    head :bad_request
  end
end
```

Or use the dispatcher when one URL handles all 3 actions:

```ruby
event = DigiwinDsp::Webhooks.parse(request.raw_post, action: params[:action])
case event
when DigiwinDsp::Webhooks::InventoryUpdate then ...
when DigiwinDsp::Webhooks::LogisticsUpdate then event.tracking_number
when DigiwinDsp::Webhooks::InvoiceUpdate   then event.invoices.each { |inv| ... }
end
```

> ⚠️ **DSP does NOT sign inbound webhooks.** There is no HMAC header. Defend the callback endpoint with:
> - HTTPS-only — `WebhookSubscription` rejects non-`https://` addresses at registration time (DSP's own spec mandates HTTPS callbacks)
> - An unguessable URL path (treat it as a secret)
> - An IP allowlist for DSP's egress range if your network team can get one
> - Replying `200 OK` within 30 seconds (DSP will retry and may eventually block your endpoint if too many calls fail)
> - **Idempotency by `form_no` / `invoice_number` / etc. on your side** — DSP may retry the same event

### Background jobs

The gem is synchronous on purpose. Wrap calls in your own job runner:

```ruby
class SyncOrderToDigiwinJob < ApplicationJob
  retry_on DigiwinDsp::RateLimitError, wait: :polynomially_longer, attempts: 5
  discard_on DigiwinDsp::DuplicateRequestError

  def perform(order_id)
    order = Order.find(order_id)
    DigiwinDsp::Resources::Order.create(order.to_dsp_payload, idempotency_key: "order-#{order.id}")
  end
end
```

## Error handling

All exceptions inherit from `DigiwinDsp::Error` and carry structured attributes safe for logging: `#code`, `#dsp_message`, `#http_status`, `#request_id`. The raw response body is **intentionally not exposed** on exceptions to prevent PII leakage to error reporters like Sentry/Rollbar that serialize exception instance variables.

| Exception | Raised when |
|---|---|
| `DigiwinDsp::ConfigurationError` | `api_key` missing at request time |
| `DigiwinDsp::ValidationError` | Required field missing locally, or DSP returns `WrongStatus:` / `Processing:取消訂單處理中` / HTTP 400 |
| `DigiwinDsp::AuthenticationError` | HTTP 401 / 403 |
| `DigiwinDsp::DuplicateRequestError` | DSP returns `Duplicated:` or HTTP 409 |
| `DigiwinDsp::RateLimitError` | DSP returns `Processing:資料處理中` (retryable) or persistent HTTP 429 |
| `DigiwinDsp::ServerError` | DSP returns `系統異常:` or HTTP 5xx that exhausts retries |
| `DigiwinDsp::NetworkError` | TCP connect failure or timeout |
| `DigiwinDsp::Error` | Catch-all (unmapped failure message or unexpected status) |

> ⚠️ Digiwin DSP returns **HTTP 200** even on application-level failure. The gem parses the response body's `Status` / `Message` fields and raises the appropriate typed exception so callers can rescue normally.

```ruby
begin
  DigiwinDsp::Resources::Order.create(record)
rescue DigiwinDsp::DuplicateRequestError
  Rails.logger.info("Order already pushed, skipping")
rescue DigiwinDsp::ValidationError => e
  Rails.logger.error("Payload rejected: #{e.dsp_message}")
  raise
rescue DigiwinDsp::RateLimitError, DigiwinDsp::ServerError
  raise   # let the job retry
end
```

## Custom `digi_header`

By default the gem **omits `digi_header`** from the request body (it's only required for certain custom Digiwin integrations). If your DSP setup expects one, pass it through:

```ruby
DigiwinDsp::Resources::Order.create(
  record,
  digi_header: {
    "digi_host"    => { "prod" => "EC-SHOP", "ip" => "10.0.0.42", "timestamp" => "20260520123456789" },
    "digi_service" => { "prod" => "ECP", "name" => "salesorder.add" }
  }
)
```

## Development

```bash
bin/setup              # bundle install
bundle exec rspec      # run the full test suite (134 examples, 100% coverage)
bundle exec rubocop    # lint
bin/console            # IRB with the gem loaded
```

The full DSP OpenAPI 3.1 specs live under `docs/dsp-specs/`. If Digiwin updates them, replace the YAML files and re-run the test suite — the `REQUIRED_FIELDS` constants in each serializer pin the contract.

## Contributing

1. Fork & branch
2. `bin/setup`
3. Write tests first (TDD); ensure `bundle exec rspec` and `bundle exec rubocop` are green
4. Open a PR

## License

MIT. See [`LICENSE.txt`](./LICENSE.txt).
