# frozen_string_literal: true

class SafeUrl
  ALLOWED_SCHEMES = %w[http https].freeze

  def self.sanitize(url)
    return '#' if url.blank?

    uri = URI.parse(url.to_s)
    safe_scheme = ALLOWED_SCHEMES.include?(uri.scheme)
    safe_relative = uri.scheme.nil? && uri.path.present?
    return uri.to_s if safe_scheme || safe_relative

    '#'
  rescue StandardError
    '#'
  end
end
