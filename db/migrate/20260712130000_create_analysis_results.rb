# frozen_string_literal: true

# Historical, append-only store for output from the ensl_analysis Python
# pipeline: per-player skill/rating values (skill, skill_mlt, skill_dl,
# skill_os*, win_ratio, ...) and per-model aggregate metrics (accuracy,
# roc_auc, ...). One row per (batch, model, metric, subject). `steamid` is
# null for model-level aggregate metrics that aren't tied to a player.
#
# `batch_id` matches the id the Python exporter assigns to each export run
# (NDJSON+lz4), so this table is intentionally never pruned/overwritten --
# re-importing the same batch is expected to be a harmless no-op once the
# importer is written, not something this migration enforces on its own.
class CreateAnalysisResults < ActiveRecord::Migration[8.1]
  def change
    create_table :analysis_results, id: :integer, charset: 'utf8mb4', collation: 'utf8mb4_general_ci' do |t|
      t.integer :batch_id
      t.string :steamid
      t.string :model, null: false
      t.string :metric, null: false
      t.float :value, null: false
      t.integer :milestone
      t.datetime :created_at, precision: nil, null: false
    end

    add_index :analysis_results, :steamid
    add_index :analysis_results, %i[model metric]
    add_index :analysis_results, :batch_id
    add_index :analysis_results, %i[batch_id model metric steamid milestone],
              unique: true, name: 'index_analysis_results_on_batch_and_subject'
  end
end
