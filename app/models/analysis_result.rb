# frozen_string_literal: true

# == Schema Information
#
# Table name: analysis_results
#
#  id         :integer          not null, primary key
#  batch_id   :integer          not null
#  model      :string(255)      not null
#  digest     :binary(16)       not null
#  field      :string(255)      not null
#  value      :float(53)
#  text_value :text(65535)
#  created_at :datetime         not null
#
# Indexes
#
#  index_analysis_results_on_batch_id                     (batch_id)
#  index_analysis_results_on_batch_model_digest_field     (batch_id, model, digest, field) UNIQUE
#  index_analysis_results_on_batch_model_field_digest     (batch_id, model, field, digest)
#

# Generic typed cells from the non-raw analysis exports. A digest identifies
# one source row; each source column is persisted as a separate field cell.
class AnalysisResult < ApplicationRecord
  CURRENT_SNAPSHOT_BATCH_ID = 0

  scope :current_snapshot, -> { where(batch_id: CURRENT_SNAPSHOT_BATCH_ID) }
  scope :historical, -> { where.not(batch_id: CURRENT_SNAPSHOT_BATCH_ID) }

  def stored_value
    text_value.nil? ? value : text_value
  end

  def self.rows_from(scope)
    scope.find_each.each_with_object({}) do |cell, rows|
      (rows[cell.digest] ||= {})[cell.field] = cell.stored_value
    end.values
  end

  def self.user_steamids(batch_id)
    rows_from(historical.where(batch_id: batch_id, model: 'users').where(field: %w[id steam_id]))
      .each_with_object({}) do |row, steamids|
      user_id = row['id']
      steam_id = row['steam_id']
      steamids[user_id.to_i] = steam_id if user_id && steam_id.present?
    end
  end
end
