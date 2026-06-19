# frozen_string_literal: true

# Configure ruby-openid to use system CA bundle explicitly (for production containers)
begin
  ca_file = ENV['SSL_CERT_FILE'].presence || '/etc/ssl/certs/ca-certificates.crt'
  ca_path = ENV['SSL_CERT_DIR'].presence || '/etc/ssl/certs'

  ENV['SSL_CERT_FILE'] = ca_file
  ENV['SSL_CERT_DIR'] = ca_path

  require 'openid'
  require 'openid/util'
  require 'openid/standard_fetcher'

  if defined?(OpenID::Util::HTTP)
    OpenID::Util::HTTP.ca_file = ca_file if OpenID::Util::HTTP.respond_to?(:ca_file=)
    OpenID::Util::HTTP.ca_path = ca_path if OpenID::Util::HTTP.respond_to?(:ca_path=)
  end

  if defined?(OpenID::StandardFetcher)
    fetcher = OpenID::StandardFetcher.new
    fetcher.ca_file = ca_file if fetcher.respond_to?(:ca_file=)
    fetcher.ca_path = ca_path if fetcher.respond_to?(:ca_path=)
    OpenID.fetcher = fetcher if OpenID.respond_to?(:fetcher=)
  end
rescue LoadError
  # OpenID not available; ignore
end
