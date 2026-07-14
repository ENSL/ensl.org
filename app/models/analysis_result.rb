# frozen_string_literal: true

# == Schema Information
#
# Table name: analysis_results
#
#  id         :integer          not null, primary key
#  batch_id   :integer          not null
#  steamid    :string(255)
#  model      :string(255)      not null
#  metric     :string(255)      not null
#  value      :float            not null
#  milestone  :integer
#  created_at :datetime         not null
#
# Indexes
#
#  index_analysis_results_on_steamid                     (steamid)
#  index_analysis_results_on_model_and_metric             (model, metric)
#  index_analysis_results_on_batch_id                     (batch_id)
#  index_analysis_results_on_batch_and_subject             (batch_id, model, metric, steamid, milestone) UNIQUE
#

# Historical, append-only output from the ensl_analysis Python pipeline
# (per-player skill/rating values plus per-model aggregate metrics). See the
# CreateAnalysisResults migration for the full rationale.
#
# WIP: intentionally barebones.
class AnalysisResult < ApplicationRecord
  belongs_to :user, primary_key: 'steamid', foreign_key: 'steamid', optional: true, inverse_of: false

  # Reserved batch_id for overwritable "current state" snapshots (map
  # balance, time-of-week activity, etc.) that aren't tied to a specific
  # export batch and aren't per-player history. Real export batches always
  # get their own (positive) batch_id from the Python exporter, so rows
  # imported under this sentinel upsert in place via
  # index_analysis_results_on_batch_and_subject on every re-import instead
  # of accumulating like the rest of this table. See
  # AnalysisBatchImportService for what gets imported under which scope.
  CURRENT_SNAPSHOT_BATCH_ID = 0

  # Sentinel values for the two other nullable columns in the unique index
  # (index_analysis_results_on_batch_and_subject). NULL is deliberately never
  # written for either: MySQL never treats two NULLs as equal for unique-index
  # purposes, so rows with a real NULL here would silently bypass upsert
  # dedup and accumulate duplicates on every re-import instead of being
  # updated in place. AnalysisBatchImportService normalizes both before
  # writing; use these same sentinels when querying "no subject"/"no
  # milestone" rows (e.g. the model-level aggregates under `metrics`).
  NO_STEAMID = ''
  NO_MILESTONE = -1

  scope :current_snapshot, -> { where(batch_id: CURRENT_SNAPSHOT_BATCH_ID) }
  scope :historical, -> { where.not(batch_id: CURRENT_SNAPSHOT_BATCH_ID) }
end
