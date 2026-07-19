# frozen_string_literal: true

require 'rails_helper'
require 'base64'

RSpec.describe Passkeys::Base64Url do
  let(:decoder_class) do
    Class.new do
      include Passkeys::Base64Url

      def decode(value)
        send(:decode_base64url, value)
      end
    end
  end

  let(:decoder) { decoder_class.new }

  it 'decodes URL-safe base64 values without padding' do
    encoded = Base64.urlsafe_encode64('passkey-data', padding: false)

    expect(decoder.decode(encoded)).to eq('passkey-data')
  end

  it 'decodes URL-safe base64 values that already contain padding' do
    encoded = Base64.urlsafe_encode64('abc123', padding: true)

    expect(decoder.decode(encoded)).to eq('abc123')
  end
end
