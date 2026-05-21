# frozen_string_literal: true

RSpec.describe DigiwinDsp::Configuration do
  let(:env_keys) do
    %w[DIGIWIN_DSP_API_KEY DIGIWIN_DSP_API_SECRET DIGIWIN_DSP_PLATFORM_ID DIGIWIN_DSP_ENV DIGIWIN_DSP_BASE_URL]
  end
  let(:saved_env) { env_keys.to_h { |k| [k, ENV.fetch(k, nil)] } }

  around do |example|
    env_keys.each { |k| ENV.delete(k) }
    DigiwinDsp.reset_configuration!
    example.run
  ensure
    saved_env.each { |k, v| v.nil? ? ENV.delete(k) : ENV[k] = v }
    DigiwinDsp.reset_configuration!
  end

  describe "defaults" do
    it "defaults environment to :sandbox" do
      expect(described_class.new.environment).to eq(:sandbox)
    end

    it "defaults timeout to 10 seconds" do
      expect(described_class.new.timeout).to eq(10)
    end

    it "defaults open_timeout to 5 seconds" do
      expect(described_class.new.open_timeout).to eq(5)
    end

    it "defaults logger to a Logger" do
      expect(described_class.new.logger).to be_a(Logger)
    end

    it "defaults allowed_hosts to the official Digiwin DSP host" do
      expect(described_class.new.allowed_hosts).to eq(["digiwindsp.digiwin.com"])
    end
  end

  describe "block-style configure" do
    it "sets api_key, api_secret, and environment via DigiwinDsp.configure" do
      DigiwinDsp.configure do |c|
        c.api_key = "abc123"
        c.api_secret = "secret"
        c.environment = :production
      end

      expect(DigiwinDsp.configuration.api_key).to eq("abc123")
      expect(DigiwinDsp.configuration.api_secret).to eq("secret")
      expect(DigiwinDsp.configuration.environment).to eq(:production)
    end
  end

  describe "ENV fallback" do
    it "reads api_key from DIGIWIN_DSP_API_KEY" do
      ENV["DIGIWIN_DSP_API_KEY"] = "from-env"
      expect(described_class.new.api_key).to eq("from-env")
    end

    it "reads api_secret from DIGIWIN_DSP_API_SECRET" do
      ENV["DIGIWIN_DSP_API_SECRET"] = "secret-env"
      expect(described_class.new.api_secret).to eq("secret-env")
    end

    it "reads platform_id from DIGIWIN_DSP_PLATFORM_ID" do
      ENV["DIGIWIN_DSP_PLATFORM_ID"] = "acme_storefront_test"
      expect(described_class.new.platform_id).to eq("acme_storefront_test")
    end

    it "reads environment from DIGIWIN_DSP_ENV as a symbol" do
      ENV["DIGIWIN_DSP_ENV"] = "production"
      expect(described_class.new.environment).to eq(:production)
    end

    it "prefers explicit assignment over ENV" do
      ENV["DIGIWIN_DSP_API_KEY"] = "from-env"
      config = described_class.new
      config.api_key = "explicit"
      expect(config.api_key).to eq("explicit")
    end
  end

  describe "#base_url" do
    it "resolves to the UAT URL when environment is :sandbox" do
      config = described_class.new
      config.environment = :sandbox
      expect(config.base_url).to eq("https://digiwindsp.digiwin.com/DSP_UAT/api/DSP")
    end

    it "resolves to the production URL when environment is :production" do
      config = described_class.new
      config.environment = :production
      expect(config.base_url).to eq("https://digiwindsp.digiwin.com/DSP/api/DSP")
    end

    it "honors an explicit base_url override when its host is allow-listed" do
      config = described_class.new
      config.allowed_hosts = ["mock.local"]
      config.base_url = "https://mock.local"
      expect(config.base_url).to eq("https://mock.local")
    end

    it "reads base_url from DIGIWIN_DSP_BASE_URL env var when allow-listed" do
      ENV["DIGIWIN_DSP_BASE_URL"] = "https://override.example.com"
      config = described_class.new
      config.allowed_hosts = ["override.example.com"]
      expect(config.base_url).to eq("https://override.example.com")
    end

    it "raises for an unknown environment" do
      config = described_class.new
      config.environment = :staging
      expect { config.base_url }.to raise_error(DigiwinDsp::ConfigurationError, /unknown environment/i)
    end
  end

  describe "#base_url SSRF + HTTPS guard" do
    it "rejects an http:// override (no downgrade)" do
      config = described_class.new
      config.allowed_hosts = ["mock.local"]
      config.base_url = "http://mock.local"
      expect { config.base_url }.to raise_error(DigiwinDsp::ConfigurationError, /https/i)
    end

    it "rejects a host not in allowed_hosts" do
      config = described_class.new
      config.base_url = "https://evil.example.com"
      expect { config.base_url }.to raise_error(DigiwinDsp::ConfigurationError, /allowed_hosts|not allowed|evil\.example\.com/i)
    end

    it "rejects an internal metadata host even if scheme is http" do
      config = described_class.new
      config.base_url = "http://169.254.169.254/latest/meta-data/"
      expect { config.base_url }.to raise_error(DigiwinDsp::ConfigurationError)
    end

    it "rejects a malformed URL" do
      config = described_class.new
      config.base_url = "ht!tp:::/badness"
      expect { config.base_url }.to raise_error(DigiwinDsp::ConfigurationError)
    end

    it "accepts any host when explicitly added to allowed_hosts" do
      config = described_class.new
      config.allowed_hosts = ["internal.example.com"]
      config.base_url = "https://internal.example.com/api"
      expect(config.base_url).to eq("https://internal.example.com/api")
    end
  end

  describe "#validate!" do
    it "raises ConfigurationError when api_key is missing" do
      config = described_class.new
      expect { config.validate! }.to raise_error(DigiwinDsp::ConfigurationError, /api_key/)
    end

    it "does not raise when api_key is present" do
      config = described_class.new
      config.api_key = "abc"
      expect { config.validate! }.not_to raise_error
    end
  end
end
