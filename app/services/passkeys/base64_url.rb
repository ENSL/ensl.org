# frozen_string_literal: true

module Passkeys
  module Base64Url
    private

    def decode_base64url(value)
      str = value.to_s.tr('-_', '+/')
      str += '=' * ((4 - (str.length % 4)) % 4)
      Base64.decode64(str)
    end
  end
end
