# digiwin_dsp

Ruby client for the Digiwin DSP **自有官網模組** API. Designed to be called from a Ruby on Rails 自有官網 (own website) and push order, cancel, invoice, and return events into the Digiwin ERP via the DSP gateway.

See [`CLAUDE.md`](./CLAUDE.md) for the design contract and conventions.

## Status

Early scaffolding. Endpoints implemented incrementally — see `docs/dsp-api-spec.md` for the source of truth on the wire format.

## Quick start

```ruby
gem "digiwin_dsp"
```

```ruby
DigiwinDsp.configure do |c|
  c.api_key     = ENV.fetch("DIGIWIN_DSP_API_KEY")
  c.api_secret  = ENV.fetch("DIGIWIN_DSP_API_SECRET")
  c.environment = :sandbox          # or :production
  c.logger      = Rails.logger
end
```

## Development

```bash
bin/setup            # bundle install
bundle exec rspec    # run tests
bundle exec rubocop  # lint
bin/console          # IRB with the gem loaded
```

## License

MIT. See [`LICENSE.txt`](./LICENSE.txt).
