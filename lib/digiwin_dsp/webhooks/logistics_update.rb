# frozen_string_literal: true

module DigiwinDsp
  module Webhooks
    # Fired by DSP when a shipment changes state (handed off to carrier,
    # delivered, etc.). See docs/dsp-specs/DSPOOFFICIAL100.yaml under
    # "倉儲貨態更新 wms/logistics/package/update".
    class LogisticsUpdate < Event
      def form_no          = request["form_no"]
      def func_name        = request["func_name"]
      def status_date      = request["status_date"]
      def status_time      = request["status_time"]
      def tracking_number  = request["tracking_number"]
      def distributor_code = request["distributor_code"]
      def message          = request["message"]
    end
  end
end
