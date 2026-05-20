# digiwin_dsp

[![Ruby](https://img.shields.io/badge/ruby-%E2%89%A53.2-CC342D)](https://www.ruby-lang.org/)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](./LICENSE.txt)

Ruby client for the Digiwin DSP **自有官網模組** (Official Website Module) API. Lets a Rails 自有官網 push orders, cancellations, invoice updates, and returns into the Digiwin ERP through the DSP gateway.

| Operation | Resource | Endpoint |
|---|---|---|
| 新增訂單 | `DigiwinDsp::Resources::Order` | `POST /v1/SalesOrder/add` |
| 取消訂單 | `DigiwinDsp::Resources::Cancellation` | `POST /v1/SalesOrder/cancel` |
| 發票更新 | `DigiwinDsp::Resources::Invoice` | `POST /v1/SalesOrder/invoice` |
| 退貨 | `DigiwinDsp::Resources::Return` | `POST /v1/SalesOrder/return` |

See [`CLAUDE.md`](./CLAUDE.md) for the design contract and [`docs/dsp-api-spec.md`](./docs/dsp-api-spec.md) (plus `docs/dsp-specs/*.yaml`) for the wire spec.

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

| Setting | ENV var | Default |
|---|---|---|
| `api_key` | `DIGIWIN_DSP_API_KEY` | _(required)_ |
| `api_secret` | `DIGIWIN_DSP_API_SECRET` | `nil` |
| `platform_id` | `DIGIWIN_DSP_PLATFORM_ID` | `nil` |
| `environment` | `DIGIWIN_DSP_ENV` | `:sandbox` |
| `base_url` | `DIGIWIN_DSP_BASE_URL` | resolved from `environment` |
| `timeout` | — | `10` |
| `open_timeout` | — | `5` |
| `logger` | — | `Logger.new(IO::NULL)` |

Base URLs (resolved from `environment`):

- `:sandbox` → `https://digiwindsp.digiwin.com/DSP_UAT/api/DSP`
- `:production` → `https://digiwindsp.digiwin.com/DSP/api/DSP`

See [`.env.local.example`](./.env.local.example) for a starter env file.

## Usage

Each resource exposes a single `#create(records, idempotency_key:, digi_header:)` method that returns the parsed `response_detail` array on success or raises a typed exception on failure.

### Create an order

```ruby
record = {
  "platform_id"     => "acme_storefront_test",
  "create_datetime" => Time.now.strftime("%Y-%m-%d %H:%M:%S"),
  "site_no"         => "acme_storefront_test",
  "form_no"         => "WEB202605200001",     # 官網訂單編號
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
  "order_status"    => "3",                   # 3 = 新增
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

### Idempotency

Pass `idempotency_key:` to attach an `X-Idempotency-Key` request header. DSP also dedupes server-side by `form_no + platform_id` and returns `Duplicated:訂單不可重複` on a re-send (mapped to `DuplicateRequestError`).

```ruby
DigiwinDsp::Resources::Order.create(record, idempotency_key: "order-#{record['form_no']}")
```

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

All exceptions inherit from `DigiwinDsp::Error` and carry rich attributes (`#code`, `#dsp_message`, `#http_status`, `#request_id`, `#response_body`).

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
bundle exec rspec      # run the full test suite (127 examples)
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
