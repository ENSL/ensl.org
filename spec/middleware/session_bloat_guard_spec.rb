# frozen_string_literal: true

require 'rails_helper'

# Reproduces the exact key shapes seen in the reported production CookieOverflow: OpenID
# discovery debris and omniauth handshake keys (written directly into the session by the
# omniauth-openid strategy, which runs as its own Rack middleware before any Rails controller
# sees the request), plus a stale Steam sign-up cache left over after the user is logged in.
# Left unchecked, that combination pushes the cookie past Rails' 4KB limit on the next commit.
RSpec.describe SessionBloatGuard do
  let(:inner_app) { ->(_env) { [200, {}, ['ok']] } }
  let(:middleware) { described_class.new(inner_app) }

  let(:openid_endpoint) do
    {
      '@claimed_id' => nil,
      '@server_url' => 'https://steamcommunity.com/openid/login',
      '@type_uris' => ['http://specs.openid.net/auth/2.0/server'],
      '@local_id' => nil,
      '@canonical_id' => nil,
      '@used_yadis' => true,
      '@display_identifier' => nil
    }
  end

  def build_session(logged_in:)
    {
      'OpenID::Consumer::DiscoveredServices::OpenID::Consumer::' => {
        'starting_url' => 'http://steamcommunity.com/openid',
        'yadis_url' => 'https://steamcommunity.com/openid',
        'services' => [],
        'current' => openid_endpoint
      },
      'OpenID::Consumer::last_requested_endpoint' => openid_endpoint,
      'omniauth.origin' => 'http://localhost:4000/',
      'omniauth.params' => {},
      'cached_user' => { id: 176, username: 'example_user', steamid: '0:1:1511705' }.to_json,
      'verified_steamid' => '0:1:1511705',
      'passkey_login' => { 'challenge' => 'abc', 'user_id' => nil, 'expires_at' => 5.minutes.from_now.to_i },
      'return_to' => 'http://localhost:4000/halloffame',
      'user' => (logged_in ? 176 : nil)
    }
  end

  it 'strips OpenID/omniauth handshake debris and the stale Steam cache once the user is logged in' do
    session = build_session(logged_in: true)

    middleware.call('rack.session' => session)

    expect(session.keys).to contain_exactly('passkey_login', 'return_to', 'user')
  end

  it 'strips OpenID/omniauth handshake debris but keeps the Steam sign-up cache for anonymous visitors' do
    session = build_session(logged_in: false)

    middleware.call('rack.session' => session)

    expect(session.keys).to contain_exactly('cached_user', 'verified_steamid', 'passkey_login', 'return_to', 'user')
  end

  it 'calls the inner app and returns its response untouched' do
    status, headers, body = middleware.call('rack.session' => {})

    expect([status, headers, body]).to eq([200, {}, ['ok']])
  end

  it 'is a no-op when the request has no session' do
    expect { middleware.call({}) }.not_to raise_error
  end

  it 'wipes the whole session as a last resort when pruning known junk still leaves it oversized' do
    session = build_session(logged_in: false)
    # Simulate leftover bloat that isn't one of the known keys (e.g. a future/unknown leak,
    # or the same debris repeated across several failed attempts).
    session['some_other_unknown_bloat'] = 'x' * 6000

    middleware.call('rack.session' => session)

    expect(session).to be_empty
  end

  it 'leaves a normally sized session untouched' do
    session = { 'user' => 176, 'return_to' => '/halloffame' }

    middleware.call('rack.session' => session)

    expect(session).to eq('user' => 176, 'return_to' => '/halloffame')
  end

  it 'prunes bloat written by inner middleware/controllers (e.g. OmniAuth) after the app call, before commit' do
    # This is the real-world sequence: OmniAuth::Builder and the controller both run as part
    # of `inner_app` here, since they sit *inside* this middleware in the Rack stack. A guard
    # that only runs before @app.call would miss bloat they write, and the session store
    # (which sits outside this middleware) would then commit an oversized cookie.
    inner_app_that_adds_bloat = lambda do |env|
      env['rack.session'].merge!(build_session(logged_in: false))
      [200, {}, ['ok']]
    end
    middleware = described_class.new(inner_app_that_adds_bloat)
    session = {}

    middleware.call('rack.session' => session)

    expect(session.keys).to contain_exactly('cached_user', 'verified_steamid', 'passkey_login', 'return_to', 'user')
  end
end
