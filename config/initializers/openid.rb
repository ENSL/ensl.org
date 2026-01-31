# Configure ruby-openid to use system CA bundle explicitly (for production containers)
begin
  require 'openid/util'

  ca_file = ENV['SSL_CERT_FILE'].presence || '/etc/ssl/certs/ca-certificates.crt'
  ca_path = ENV['SSL_CERT_DIR'].presence || '/etc/ssl/certs'

  if defined?(OpenID::Util::HTTP)
    OpenID::Util::HTTP.ca_file = ca_file if OpenID::Util::HTTP.respond_to?(:ca_file=)
    OpenID::Util::HTTP.ca_path = ca_path if OpenID::Util::HTTP.respond_to?(:ca_path=)
  end
rescue LoadError
  # OpenID not available; ignore
end
