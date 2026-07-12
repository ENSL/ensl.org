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
# WIP: intentionally barebones. No validations/scopes/business logic yet --
# the batch importer that will populate this table is written separately.
class AnalysisResult < ApplicationRecord
  belongs_to :user, primary_key: 'steamid', foreign_key: 'steamid', optional: true, inverse_of: false
end
