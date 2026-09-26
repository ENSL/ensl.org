# frozen_string_literal: true

# Replaces the original scalar-result layout with a generic cell store. The
# existing table only contains derived Parquet imports, so it is deliberately
# truncated rather than translated from the old overloaded columns.
class RestructureAnalysisResultsAsCells < ActiveRecord::Migration[8.1]
  def up
    # rubocop:disable Rails/BulkChangeTable, Rails/NotNullColumn
    # The table is empty; ordered MySQL alters are intentional.
    execute 'TRUNCATE TABLE analysis_results'

    remove_index :analysis_results, name: 'index_analysis_results_on_batch_and_subject'
    remove_index :analysis_results, name: 'index_analysis_results_on_model_and_metric'
    remove_index :analysis_results, name: 'index_analysis_results_on_steamid'

    remove_column :analysis_results, :metric
    remove_column :analysis_results, :milestone
    remove_column :analysis_results, :steamid

    change_column_null :analysis_results, :batch_id, false
    change_column :analysis_results, :value, :float, limit: 53, null: true
    add_column :analysis_results, :digest, :binary, limit: 16, null: false
    add_column :analysis_results, :field, :string, null: false
    add_column :analysis_results, :text_value, :text

    execute <<~SQL
      ALTER TABLE analysis_results
        MODIFY COLUMN model varchar(255) NOT NULL AFTER batch_id,
        MODIFY COLUMN digest binary(16) NOT NULL AFTER model,
        MODIFY COLUMN field varchar(255) NOT NULL AFTER digest,
        MODIFY COLUMN value double DEFAULT NULL AFTER field,
        MODIFY COLUMN text_value text DEFAULT NULL AFTER value,
        MODIFY COLUMN created_at datetime NOT NULL AFTER text_value
    SQL

    add_index :analysis_results,
              %i[batch_id model digest field],
              unique: true,
              name: 'index_analysis_results_on_batch_model_digest_field'
    add_index :analysis_results,
              %i[batch_id model field digest],
              name: 'index_analysis_results_on_batch_model_field_digest'
    # rubocop:enable Rails/BulkChangeTable, Rails/NotNullColumn
  end

  def down
    raise ActiveRecord::IrreversibleMigration, 'analysis_results was deliberately truncated'
  end
end
