# frozen_string_literal: true

# Live UAT smoke test: posts ONE synthetic order to the Digiwin DSP sandbox
# and prints the parsed response. Run with:
#
#   bundle exec ruby scripts/smoke.rb
#
# Requires .env.local with DIGIWIN_DSP_API_KEY + DIGIWIN_DSP_PLATFORM_ID.
# Hits the real UAT endpoint — NOT for production. Each run uses a unique
# form_no so DSP doesn't reject as duplicate.

require "json"
require_relative "../lib/digiwin_dsp"

# Tiny .env.local loader (avoid pulling dotenv as a runtime dep)
env_path = File.expand_path("../.env.local", __dir__)
abort "missing #{env_path}" unless File.exist?(env_path)
File.foreach(env_path) do |line|
  line = line.strip
  next if line.empty? || line.start_with?("#")

  k, v = line.split("=", 2)
  # ||= so caller-supplied env vars override .env.local (dotenv semantics)
  ENV[k] ||= v if k && v
end

DigiwinDsp.configure do |c|
  c.api_key     = ENV.fetch("DIGIWIN_DSP_API_KEY")
  c.platform_id = ENV.fetch("DIGIWIN_DSP_PLATFORM_ID")
  c.environment = :sandbox
  c.logger      = Logger.new($stdout).tap { |l| l.level = Logger::INFO }
end

platform  = DigiwinDsp.configuration.platform_id
unique_id = Time.now.strftime("%Y%m%d%H%M%S%L")
form_no   = ENV.fetch("FORM_NO") { "SMOKE-#{unique_id}" }

record = {
  "platform_id"     => platform,
  "create_datetime" => Time.now.strftime("%Y-%m-%d %H:%M:%S"),
  "site_no"         => platform,
  "form_no"         => form_no,
  "order_date"      => Time.now.strftime("%Y%m%d"),
  "buyer_name"      => "SmokeBuyer",
  "receiver_name"   => "SmokeReceiver",
  "pay_type"        => "9104",
  "shipping_type"   => "9102",
  "tax_type"        => "1",
  "sno"             => "1",
  "form_subno"      => "1",
  "product_no"      => "SMOKE-001",
  "product_name"    => "SmokeTest",
  "unit"            => "EA",
  "qty"             => "1",
  "free_qty"        => "0",
  "price"           => "100",
  "subtotal"        => "100",
  "payment"         => "100",
  "order_status"    => "3",
  "last_record"     => "Y"
}

puts "=" * 70
puts "POST #{DigiwinDsp.configuration.base_url}/v1/SalesOrder/add"
puts "  form_no:     #{form_no}"
puts "  platform_id: #{platform}"
puts "=" * 70

begin
  detail = DigiwinDsp::Resources::Order.create(record)
  puts "\nSUCCESS:"
  puts JSON.pretty_generate(detail)
rescue DigiwinDsp::Error => e
  puts "\n#{e.class}: #{e.message}"
  puts "  code:        #{e.code.inspect}"
  puts "  dsp_message: #{e.dsp_message.inspect}"
  puts "  http_status: #{e.http_status.inspect}"
  puts "  request_id:  #{e.request_id.inspect}"
  exit 1
end
