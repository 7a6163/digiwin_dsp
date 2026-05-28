# frozen_string_literal: true

require "faraday"
require "faraday/retry"

module DigiwinDsp
  class Client
    RETRY_STATUSES = [429, 500, 502, 503, 504].freeze
    # Exponential backoff: ~0.5s, ~1s, ~2s between attempts, ±50% jitter so
    # multiple Rails workers retrying the same upstream blip don't synchronize
    # into a thundering herd against DSP.
    RETRY_MAX = 3
    RETRY_INTERVAL = 0.5
    RETRY_BACKOFF_FACTOR = 2
    RETRY_INTERVAL_RANDOMNESS = 0.5
    USER_AGENT = "digiwin_dsp/#{VERSION} (Faraday/#{Faraday::VERSION})".freeze

    STATUS_ERROR_MAP = {
      400 => ValidationError,
      401 => AuthenticationError,
      403 => AuthenticationError,
      409 => DuplicateRequestError,
      429 => RateLimitError
    }.freeze

    # Patterns DSP returns in the response body's `Message` field on Status=Failure.
    # The Chinese substrings are verbatim DSP responses — see docs/dsp-api-spec.md.
    # Live DSP prepends the offending form_no to Message (e.g.
    # "ORDER-123:Duplicated:訂單不可重複"), so we substring-match rather than
    # anchor with \A. Order matters: more-specific patterns first.
    ENVELOPE_FAILURE_MAP = [
      [/DSP 序號驗證失敗/, AuthenticationError], # bad / missing DSP-api-key
      [/Duplicated:/, DuplicateRequestError], # order already exists
      [/Processing:資料處理中/, RateLimitError], # transient; retry later
      [/Processing:取消訂單處理中/, ValidationError], # cancel in flight
      [/WrongStatus:/, ValidationError], # bad payload
      [/系統異常:/, ServerError] # DSP internal error
    ].freeze

    def initialize(configuration: DigiwinDsp.configuration, authenticator: nil, base_url: nil)
      @configuration     = configuration
      @authenticator     = authenticator || Authenticator.new(configuration)
      @base_url_override = base_url
    end

    def post(path, body, idempotency_key: nil, headers: {})
      @configuration.validate!
      sanitize_request_headers!(idempotency_key, headers)
      response = connection.post(normalize_path(path)) do |req|
        req.headers["X-Idempotency-Key"] = idempotency_key if idempotency_key
        headers.each { |k, v| req.headers[k] = v }
        req.body = body
      end
      handle_response(response)
    rescue Faraday::ConnectionFailed, Faraday::TimeoutError => e
      raise NetworkError, e.message
    end

    private

    def connection
      @connection ||= Faraday.new(url: connection_base_url, headers: default_headers) do |f|
        f.request :json
        f.request :retry,
                  max: RETRY_MAX,
                  interval: RETRY_INTERVAL,
                  backoff_factor: RETRY_BACKOFF_FACTOR,
                  interval_randomness: RETRY_INTERVAL_RANDOMNESS,
                  retry_statuses: RETRY_STATUSES,
                  methods: %i[get post put patch delete]
        # max_nesting caps deserialization depth so a hostile / malformed DSP
        # response can't allocate unbounded memory (DoS guard on the parser).
        f.response :json, content_type: /\bjson\z/, parser_options: { max_nesting: 50 }
        f.response :logger, @configuration.logger, headers: false, bodies: false, log_level: :debug
        f.adapter Faraday.default_adapter
        f.options.timeout = @configuration.timeout
        f.options.open_timeout = @configuration.open_timeout
      end
    end

    def connection_base_url
      base = @base_url_override || @configuration.base_url
      base.end_with?("/") ? base : "#{base}/"
    end

    def normalize_path(path)
      path.sub(%r{\A/+}, "")
    end

    def default_headers
      {
        "User-Agent" => USER_AGENT,
        "Accept" => "application/json"
      }.merge(@authenticator.auth_headers)
    end

    def handle_response(response)
      status = response.status
      body = response.body
      return inspect_envelope(body) if status.between?(200, 299)

      raise classify_http_error(status, body)
    end

    def classify_http_error(status, body)
      klass = STATUS_ERROR_MAP[status] || (status.between?(500, 599) ? ServerError : Error)
      message = klass == Error ? "unexpected HTTP status #{status}" : http_message(status, body)
      klass.new(message, **error_attrs(status, body))
    end

    def inspect_envelope(body)
      return body unless body.is_a?(Hash)

      failure = detect_envelope_failure(body)
      return body unless failure

      raise classify_envelope_failure(failure[:message], code: failure[:code], body: body)
    end

    # Detects either envelope shape and returns {message, code} if it's a
    # failure response, or nil if it's a success / non-envelope body.
    # - DSPOOFFICIAL100: { srvver, std_data: { execution: { code, description }, response } }
    # - DSPOOFFICIAL001-005: { Status, Message, response_detail }
    def detect_envelope_failure(body)
      if (exec = body.dig("std_data", "execution"))
        return nil if exec["code"].to_s == "0"

        { message: exec["description"].to_s, code: exec["code"] }
      elsif body["Status"].to_s.casecmp("failure").zero?
        { message: body["Message"].to_s, code: body["Status"] }
      end
    end

    def classify_envelope_failure(message, code:, body:)
      klass = ENVELOPE_FAILURE_MAP.find { |regex, _| regex.match?(message) }&.last || Error
      klass.new(message, code: code, dsp_message: message, request_id: body["request_id"], http_status: 200)
    end

    def http_message(status, body)
      dsp_msg = body.is_a?(Hash) ? body["error_message"] || body["message"] : nil
      dsp_msg ? "HTTP #{status}: #{dsp_msg}" : "HTTP #{status}"
    end

    def error_attrs(status, body)
      hash = body.is_a?(Hash) ? body : {}
      {
        code: hash["error_code"] || hash["code"],
        dsp_message: hash["error_message"] || hash["message"],
        request_id: hash["request_id"],
        http_status: status
      }
    end

    # Block CRLF/LF/CR in header names and values. RFC 7230 §3.2.4 forbids
    # them and Faraday + Net::HTTP catch many forms, but not all — close
    # the gap to prevent header-injection / request-smuggling.
    def sanitize_request_headers!(idempotency_key, headers)
      sanitize_header!("X-Idempotency-Key", idempotency_key) if idempotency_key
      headers.each { |k, v| sanitize_header!(k, v) }
    end

    def sanitize_header!(name, value)
      raise ArgumentError, "invalid header value for #{name.inspect}: contains CRLF/LF/CR" if value.to_s.match?(/[\r\n]/)
      raise ArgumentError, "invalid header name #{name.inspect}: contains CRLF/LF/CR" if name.to_s.match?(/[\r\n]/)
    end
  end
end
