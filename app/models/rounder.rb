# frozen_string_literal: true

# == Schema Information
#
# Table name: rounders
#
#  id       :integer          not null, primary key
#  round_id :integer
#  steamid  :string(255)
#  team     :integer
#  share    :float
#
# Indexes
#
#  index_rounders_on_round_and_steamid (round_id, steamid) UNIQUE
#

# One player's participation in a Round, imported from the ensl_analysis
# Python pipeline's `round_users` parquet export (see RoundBatchImportService).
#
# `steamid` (rather than a `user_id` FK snapshotted at import time) is the
# link to our own User records -- same convention as AnalysisResult, though
# unlike AnalysisResult this resolves the link with a normalized lookup (see
# `user` below) instead of a plain `belongs_to`, because the pipeline's
# steamid format ("STEAM_0:1:97069") doesn't match User#steamid's normalized,
# prefix-stripped format ("0:1:97069") -- a bare `belongs_to primary_key:
# foreign_key:` comparison between those two never matches. `team` is 1 for
# marine, -1 for alien, matching the Python pipeline's convention.
class Rounder < ApplicationRecord
  TEAM_MARINES = 1
  TEAM_ALIENS = -1

  belongs_to :round

  def to_s
    user ? user.username : steamid
  end

  def user
    return nil if steamid.blank?

    @user ||= User.find_by(steamid: User.normalize_steamid(steamid))
  end
end
