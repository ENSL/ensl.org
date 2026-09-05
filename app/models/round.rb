# frozen_string_literal: true

# == Schema Information
#
# Table name: rounds
#
#  id          :integer          not null, primary key
#  server_name :string(255)
#  start_time  :datetime
#  end_time    :datetime
#  map_name    :string(255)
#  result      :integer
#
# Indexes
#
#  index_rounds_on_server_name_and_start_time (server_name, start_time) UNIQUE
#

# One NS1 round, imported from the ensl_analysis Python pipeline's `rounds`
# parquet export (see RoundBatchImportService). Not tied to any ladder
# match/team/map record -- the pipeline only knows about servers and maps by
# name, not our Server/Map/Match/Team rows.
#
# `id` here is a Rails-assigned primary key, not the Python exporter's own
# `rounds.id` -- that id is just a per-run counter, not stable across
# batches, so rows are upserted on (server_name, start_time) instead (see
# the RestructureRoundAndLogModels migration for why).
class Round < ApplicationRecord
  RESULT_MARINE_WIN = 1
  RESULT_ALIEN_WIN = 0

  has_many :rounders, dependent: :destroy
  has_many :log_lines, dependent: :destroy

  def winner_s
    case result
    when RESULT_MARINE_WIN then 'Marines'
    when RESULT_ALIEN_WIN then 'Aliens'
    end
  end

  def length
    return nil unless start_time && end_time

    total_seconds = (end_time - start_time).to_i
    format('%<minutes>02d:%<seconds>02d', minutes: total_seconds / 60, seconds: total_seconds % 60)
  end
end

