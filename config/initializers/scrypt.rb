# Ensure all scrypt operations use a consistent max_time.

require 'scrypt'

ENV['SCRYPT_MAX_TIME'] ||= '1'

value = ENV['SCRYPT_MAX_TIME'].to_s.strip
if value.length > 0
  max_time = value.to_f
  if max_time > 0
    SCrypt::Engine.calibrate!(max_time: max_time)
  end
end
