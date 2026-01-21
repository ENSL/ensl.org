require 'rails_helper'
require 'steamid'

RSpec.describe 'Steam OmniAuth callback', type: :request do
  before do
    OmniAuth.config.test_mode = true
  end

  let(:uid) { '76561197960287930' }
  let(:auth_hash) do
    OmniAuth::AuthHash.new(provider: 'steam', uid: uid, info: { nickname: 'steam_nick', name: 'Real Name' })
  end

  it 'logs in existing user with matching steamid and updates lastvisit' do
    steamid = SteamID.from_steamID64(uid)
    user = create(:user, steamid: steamid)

    OmniAuth.config.mock_auth[:steam] = auth_hash
    post '/auth/steam/callback'

    expect(flash[:notice]).to be_present
    user.reload
    expect(user.lastvisit).to be_within(10).of(Time.now.utc)
  end

  it 'builds and caches a new user when steam account not present' do
    OmniAuth.config.mock_auth[:steam] = auth_hash
    # avoid rendering the full new-user view (which may call route helpers)
    allow_any_instance_of(UsersController).to receive(:render).and_return(true)

    post '/auth/steam/callback'

    # controller stores cached user JSON in session for sign-up flow
    expect(session[:cached_user]).to be_present
    cached = JSON.parse(session[:cached_user])
    expect(cached['username']).to match(/^steam_nick/)
  end
end
