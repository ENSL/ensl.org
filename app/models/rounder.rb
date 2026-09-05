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
# link to our own User records, resolved live via `user` below -- same
# convention as AnalysisResult. `team` is 1 for marine, -1 for alien,
# matching the Python pipeline's convention.
class Rounder < ApplicationRecord
  TEAM_MARINES = 1
  TEAM_ALIENS = -1

  belongs_to :round
  belongs_to :user, primary_key: 'steamid', foreign_key: 'steamid', optional: true, inverse_of: false

  def to_s
    user ? user.username : steamid
  end
end

