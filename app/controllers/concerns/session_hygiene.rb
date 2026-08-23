# frozen_string_literal: true

# Prunes OmniAuth/OpenID handshake debris from the session on every request. See
# SessionBloatGuard for why the same pruning also has to happen at the Rack middleware
# level (by the time a controller runs, OmniAuth may already have committed a cookie).
module SessionHygiene
  extend ActiveSupport::Concern

  included do
    before_action :purge_stale_session_data
  end

  private

  def purge_stale_session_data
    # NOTE: session is ActionDispatch::Request::Session, which only supports #keys/#each,
    # not the Hash-only #each_key rubocop wants to suggest here.
    session.keys.each do |key| # rubocop:disable Style/HashEachMethods
      session.delete(key) if key.to_s.start_with?('OpenID::', 'omniauth.')
    end
    return unless cuser

    session.delete(:cached_user)
    session.delete(:verified_steamid)
    session.delete(:steam_registration_profile)
  end
end
