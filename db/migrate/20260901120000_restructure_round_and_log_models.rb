# frozen_string_literal: true

# Rebuilds log_events/log_files/log_lines/rounds/rounders around the Python
# ensl_analysis pipeline's parquet output (see ea_schema.py in the
# ensl_analysis repo) instead of the old Ruby-side NS1 log parser.
#
# log_events is dropped entirely: the pipeline's log_lines.event_type is a
# plain string, there's no lookup-table equivalent to import into.
#
# The remaining four tables are dropped and recreated (rather than altered
# column-by-column) because none of the old ladder-linking columns
# (match_id/team1_id/team2_id/commander_id/map_id/server_id/user_id/...)
# have a parquet counterpart, and the production DB has no useful data in
# any of them to preserve.
#
# None of the ids in the parquet export (rounds.id, log_files.id, ...) are
# trustworthy as our primary keys -- they're just per-run counters on the
# Python side, reset by --rebuild and not guaranteed stable between export
# batches (see log_parser.py). So every table here is keyed for natural-key
# upserts (RoundBatchImportService resolves the parquet ids to these keys
# before importing) instead of storing the Python-assigned ids directly:
#   - log_files:            sha256 of the log file's bytes
#   - rounds:                (server_name, start_time), taken from in-log timestamps
#   - rounders (round_users): (round, steamid)
#   - log_lines:             (log_file, digest of raw_text)
class RestructureRoundAndLogModels < ActiveRecord::Migration[8.1]
  def up
    drop_table :log_events

    drop_table :log_lines
    drop_table :rounders
    drop_table :rounds
    drop_table :log_files

    create_table :log_files, id: :integer, charset: 'utf8mb4', collation: 'utf8mb4_general_ci' do |t|
      t.string :sha256, null: false
      t.string :filename
      t.string :server_name
      t.datetime :created_at, precision: nil
    end
    add_index :log_files, :sha256, unique: true

    create_table :rounds, id: :integer, charset: 'utf8mb4', collation: 'utf8mb4_general_ci' do |t|
      t.string :server_name
      t.datetime :start_time, precision: nil
      t.datetime :end_time, precision: nil
      t.string :map_name
      # 1 = marine win, 0 = alien win, NULL = round never ended (crash/log cut off).
      t.integer :result
    end
    add_index :rounds, %i[server_name start_time], unique: true, name: 'index_rounds_on_server_name_and_start_time'

    create_table :rounders, id: :integer, charset: 'utf8mb4', collation: 'utf8mb4_general_ci' do |t|
      t.integer :round_id
      t.string :steamid
      # 1 = marine, -1 = alien, matching round_users.team from the Python pipeline.
      t.integer :team
      # Fraction of the round this player was present for (join/leave-derived).
      t.float :share
    end
    add_index :rounders, :round_id
    add_index :rounders, %i[round_id steamid], unique: true, name: 'index_rounders_on_round_and_steamid'

    create_table :log_lines, id: :integer, charset: 'utf8mb4', collation: 'utf8mb4_general_ci' do |t|
      t.integer :log_file_id
      t.integer :round_id
      t.text :raw_text
      t.string :event_type
      t.string :param1
      t.string :param2
      t.string :param3
      t.string :actor_steamid
      t.string :target_steamid
      t.string :server_name
      t.datetime :created_at, precision: nil
      # sha256(raw_text), since raw_text itself is too long to index directly.
      t.string :line_digest, limit: 64
    end
    add_index :log_lines, :round_id
    add_index :log_lines, %i[log_file_id line_digest], unique: true, name: 'index_log_lines_on_log_file_and_digest'
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
