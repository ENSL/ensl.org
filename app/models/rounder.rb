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

# Cross-checks Rounder#team (as imported) against Round#observed_teams (the
# actual team seen in that round's own log lines) -- confirmed real examples
# of `round_users` importing a wrong team live in /memories/repo/round-
# timeline.md. Deliberately scoped to the `:team_check` context so it never
# runs on normal save/import (which bulk-upserts via upsert_all and skips
# validations anyway) -- only when explicitly asked, e.g.
# `rounder.valid?(:team_check)` (see script/validate_rounds.rb).
class RounderTeamValidator < ActiveModel::Validator
  # Below this many observed events for a steamid in the round, there's not
  # enough evidence either way -- stay quiet rather than guess.
  MIN_SAMPLE = 3
  # How lopsided the observed split needs to be before treating it as
  # decisive -- guards against flagging a legitimate mid-round team switch.
  MIN_AGREEMENT = 0.8

  def validate(record)
    tally = record.round.observed_teams[record.steamid]
    return if tally.blank?

    total = tally.values.sum
    return if total < MIN_SAMPLE

    observed_side, observed_count = tally.max_by { |_, count| count }
    return if observed_count.fdiv(total) < MIN_AGREEMENT

    expected_side = record.team == Rounder::TEAM_MARINES ? 'marine' : 'alien'
    return if observed_side == expected_side

    record.errors.add(:team, :disagrees_with_log_lines,
                      message: "stored as #{expected_side} but round log lines show " \
                               "#{observed_side} (#{observed_count}/#{total} events)")
  end
end

class Rounder < ApplicationRecord
  TEAM_MARINES = 1
  TEAM_ALIENS = -1

  belongs_to :round
  validates_with RounderTeamValidator, on: :team_check

  def to_s
    user ? user.username : steamid
  end

  def user
    return nil if steamid.blank?

    @user ||= User.find_by(steamid: User.normalize_steamid(steamid))
  end
end
