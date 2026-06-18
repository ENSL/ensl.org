require 'rails_helper'

RSpec.describe 'Steam OmniAuth callback', type: :request do
  before do
    OmniAuth.config.test_mode = true
  end

  let(:uid) { '76561197960287930' }
  let(:auth_hash) do
    OmniAuth::AuthHash.new(provider: 'steam', uid: uid, info: { nickname: 'steam_nick', name: 'Real Name' })
  end

  it 'logs in existing user with matching steamid and updates lastvisit' do
    steamid = User.normalize_steamid(uid)
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

  it 'hydrates the registration form from the cached user created by the callback' do
    OmniAuth.config.mock_auth[:steam] = auth_hash
    allow_any_instance_of(UsersController).to receive(:render).and_call_original

    post '/auth/steam/callback'
    cached = JSON.parse(session[:cached_user])

    get '/users/new'

    expect(response).to have_http_status(:ok)
    expect(response.body).to include(cached['username'])
  end

  context 'when Steam login fails' do
    it 'rejects XHR JavaScript callback requests before processing auth' do
      OmniAuth.config.mock_auth[:steam] = auth_hash

      post '/auth/steam/callback', headers: {
        'ACCEPT' => 'text/javascript',
        'HTTP_X_REQUESTED_WITH' => 'XMLHttpRequest'
      }

      expect(response).to have_http_status(:not_acceptable)
    end

    it 'handles missing auth_hash gracefully' do
      # Simulate OmniAuth failure by not setting mock_auth
      OmniAuth.config.mock_auth[:steam] = nil

      post '/auth/steam/callback'

      expect(response).to redirect_to(root_path)
      expect(flash[:error]).to be_present
    end

    it 'handles User.find_or_build returning nil' do
      OmniAuth.config.mock_auth[:steam] = auth_hash
      allow(User).to receive(:find_or_build).and_return(nil)

      post '/auth/steam/callback'

      expect(response).to redirect_to(root_path)
      expect(flash[:error]).to be_present
    end

    it 'handles User.find_or_build returning a non-ActiveRecord object' do
      OmniAuth.config.mock_auth[:steam] = auth_hash
      allow(User).to receive(:find_or_build).and_return(double('not-a-record'))

      post '/auth/steam/callback'

      expect(response).to redirect_to(root_path)
      expect(flash[:error]).to be_present
    end

    it 'handles exception during User.find_or_build' do
      OmniAuth.config.mock_auth[:steam] = auth_hash
      allow(User).to receive(:find_or_build).and_raise(StandardError, 'Database error')

      expect do
        post '/auth/steam/callback'
      end.to raise_error(StandardError)
    end
  end
end
