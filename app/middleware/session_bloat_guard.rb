# frozen_string_literal: true

# OmniAuth's OpenID (Steam) strategy runs as its own Rack middleware, sitting after the
# session middleware but before the request ever reaches a Rails controller. It writes
# discovery/handshake state straight into the session and never cleans it up. That means
# an ApplicationController before_action is too late to help: by the time a bloated cookie
# reaches the /auth/steam request, OmniAuth adds its own data and the commit overflows
# before any controller code runs. This middleware strips the dead weight (OpenID/omniauth
# handshake keys, plus the Steam sign-up cache once a user is already logged in) on every
# request, so it must be inserted before OmniAuth::Builder in the middleware stack.
#
# The handshake itself spans exactly two requests -- GET /auth/steam (begin phase, writes
# discovery data) and GET /auth/steam/callback (complete phase, reads it back) -- and
# rack-openid uses the Rack session as its own store for that data (see
# OpenID::Consumer.new(session, store) in rack-openid). Pruning OpenID::/omniauth. keys
# on either side of *those two requests* would delete the handshake state before rack-openid
# gets a chance to write or read it, breaking Steam login outright. So we only purge before
# the begin request (cleans up any stale data left by an abandoned earlier attempt) and
# after the callback request (the handshake is done with it by then); every other request
# is pruned on both sides as before.
#
# Pruning known keys isn't enough on its own: if a browser is already stuck with an
# oversized cookie, every request keeps re-triggering CookieOverflow before a response can
# ever be committed, so the browser never receives a smaller cookie to replace it -- the
# same broken cookie gets resent forever. As a last resort, if the session is still too big
# after pruning, wipe it entirely so the response is guaranteed to commit and the browser
# finally gets a small cookie back.
class SessionBloatGuard
  # A signed+encrypted cookie has a little under 4KB of room; stay well clear of that ceiling.
  MAX_SAFE_BYTES = 3000

  STEAM_BEGIN_PATH = '/auth/steam'
  STEAM_CALLBACK_PATH = '/auth/steam/callback'

  def initialize(app)
    @app = app
  end

  def call(env)
    path = env['PATH_INFO'].to_s

    # ActionDispatch::Session::CookieStore sits *outside* this middleware (it's part of the
    # default stack, inserted before this one runs), so it only commits the cookie after
    # @app.call returns here. Pruning only up front isn't enough: OmniAuth's OpenID strategy
    # (also inside @app, since it's `use`d after this middleware) writes its own discovery
    # keys during the request, and controllers write things like cached_user/verified_steamid
    # afterwards -- all of that lands in the session *after* the first guard call and would
    # otherwise reach the commit unchecked. Guard again on the way out, right before this
    # middleware returns control to the session store's commit.
    guard(env['rack.session'], purge_handshake: path != STEAM_CALLBACK_PATH)
    response = @app.call(env)
    guard(env['rack.session'], purge_handshake: path != STEAM_BEGIN_PATH)
    response
  end

  private

  def guard(session, purge_handshake:)
    return unless session.respond_to?(:keys)

    purge_known_junk(session, purge_handshake: purge_handshake)
    session.clear if oversized?(session)
  end

  def purge_known_junk(session, purge_handshake:)
    if purge_handshake
      # NOTE: session is ActionDispatch::Request::Session in production, which only
      # supports #keys/#each, not the Hash-only #each_key rubocop wants to suggest here.
      session.keys.each do |key| # rubocop:disable Style/HashEachMethods
        session.delete(key) if key.to_s.start_with?('OpenID::', 'omniauth.')
      end
    end
    return unless session['user']

    session.delete('cached_user')
    session.delete('verified_steamid')
  end

  def oversized?(session)
    session.to_hash.to_json.bytesize > MAX_SAFE_BYTES
  rescue StandardError
    false
  end
end
