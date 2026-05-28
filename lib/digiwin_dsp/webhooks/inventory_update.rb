# frozen_string_literal: true

module DigiwinDsp
  module Webhooks
    # Fired by DSP when an ERP-side inventory change happens.
    # See docs/dsp-specs/DSPOOFFICIAL100.yaml under
    # "庫存數量更新 product/inventory_update".
    class InventoryUpdate < Event
      def prod         = request["prod"]
      def platform_id  = request["platform_id"]
      def sale_page_id = request["sale_page_id"]
      def spec_list    = request["spec_list"] || []
    end
  end
end
