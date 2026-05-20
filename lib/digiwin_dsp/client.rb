# frozen_string_literal: true

require "faraday"
require "faraday/retry"

module DigiwinDsp
  class Client
    RETRY_STATUSES = [429, 500, 502, 503, 504].freeze
    USER_AGENT = "digiwin_dsp/#{VERSION} (Faraday/#{Faraday::VERSION})".freeze

    STATUS_ERROR_MAP = {
      400 => ValidationError,
      401 => AuthenticationError,
      403 => AuthenticationError,
      409 => DuplicateRequestError,
      429 => RateLimitError
    }.freeze

    # Order matters — more-specific patterns first.
    ENVELOPE_FAILURE_MAP = [
      [/\ADuplicated:/, DuplicateRequestError],
      [/\AProcessing:資料處理中/, RateLimitError],
      [/\AProcessing:取消訂單處理中/, ValidationError],
      [/\AWrongStatus:/, ValidationError],
      [/\A系統異常:/, ServerError]
    ].freeze

    def initialize(configuration: DigiwinDsp.configuration, authenticator: nil)
      @configuration = configuration
      @authenticator = authenticator || Authenticator.new(configuration)
    end

    def post(path, body, idempotency_key: nil, headers: {})
      @configuration.validate!
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
                  max: 3,
                  interval: 0.0,
                  backoff_factor: 1,
                  retry_statuses: RETRY_STATUSES,
                  methods: %i[get post put patch delete]
        f.response :json, content_type: /\bjson\z/
        f.response :logger, @configuration.logger, headers: false, bodies: false, log_level: :debug
        f.adapter Faraday.default_adapter
        f.options.timeout = @configuration.timeout
        f.options.open_timeout = @configuration.open_timeout
      end
    end

    def connection_base_url
      base = @configuration.base_url
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
      return body unless body.is_a?(Hash) && body["Status"].to_s.casecmp("failure").zero?

      message = body["Message"].to_s
      klass = ENVELOPE_FAILURE_MAP.find { |regex, _| regex.match?(message) }&.last || Error
      raise klass.new(message, **envelope_error_attrs(body))
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
        http_status: status,
        response_body: body
      }
    end

    def envelope_error_attrs(body)
      {
        code: body["Status"],
        dsp_message: body["Message"],
        request_id: body["request_id"],
        http_status: 200,
        response_body: body
      }
    end
  end
end
