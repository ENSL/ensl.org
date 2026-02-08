# spec/support/omniauth.rb
# Configure OmniAuth to use test mode and provide a default Steam mock.
require 'omniauth'

RSpec.configure do |config|
  config.before(:suite) do
    OmniAuth.config.test_mode = true
  end

  config.before(:each) do
    OmniAuth.config.full_host = nil if Rails.env.test?

    # Default mock — tests may override this per-example if needed
    OmniAuth.config.mock_auth[:steam] ||= OmniAuth::AuthHash.new(
      provider: 'steam',
      uid: '76561198000000000',
      info: {
        nickname: 'spec_steam_user',
        email: 'spec+steam@example.com'
      },
      extra: {
        raw_info: { 'steamid' => '76561198000000000' }
      }
    )
  end

  config.after(:each) do
    OmniAuth.config.mock_auth[:steam] = nil
  end
end
