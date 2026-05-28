# frozen_string_literal: true

module DigiwinDsp
  # Inbound webhook payload parsers for events DSP pushes to your Rails app
  # after you register a callback URL via `Resources::WebhookSubscription`.
  #
  # ⚠️ DSP does NOT sign these requests — there is no HMAC header. Defend
  # the callback endpoint with HTTPS-only, an unguessable URL path, and
  # (if possible) an IP allowlist for DSP's egress range.
  module Webhooks
    # Raised when JSON is malformed, the envelope is the wrong shape, or
    # the action is unknown to the gem. Inherits from ValidationError so
    # Rails controllers can rescue the existing DigiwinDsp::Error tree.
    class ParseError < DigiwinDsp::ValidationError; end

    # action string => constant name (lazy resolution via const_get so
    # this module file doesn't force-load the per-event classes at boot).
    ACTION_REGISTRY = {
      "product/inventory_update" => :InventoryUpdate,
      "wms/logistics/package/update" => :LogisticsUpdate,
      "invoice/update" => :InvoiceUpdate
    }.freeze

    def self.parse(raw_body, action:)
      sym = ACTION_REGISTRY[action] ||
            raise(ParseError, "unknown action #{action.inspect}; expected one of #{ACTION_REGISTRY.keys.inspect}")
      const_get(sym).parse(raw_body)
    end
  end
end
