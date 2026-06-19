# frozen_string_literal: true

# Ensure all scrypt operations use a consistent max_time.

require 'scrypt'

ENV['SCRYPT_MAX_TIME'] ||= '1'

value = ENV['SCRYPT_MAX_TIME'].to_s.strip
if value.length.positive?
  max_time = value.to_f
  SCrypt::Engine.calibrate!(max_time: max_time) if max_time.positive?
end
