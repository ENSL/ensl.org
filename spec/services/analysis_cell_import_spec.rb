# frozen_string_literal: true

require 'rails_helper'

RSpec.describe AnalysisBatchImportService do
  let(:batch_id) { 42 }
  let(:exports_dir) { Dir.mktmpdir('analysis-cell-import-spec') }
  let(:service) { described_class.new(batch_id, exports_dir: exports_dir) }

  after do
    FileUtils.remove_entry(exports_dir) if File.directory?(exports_dir)
  end

  def write_parquet(dataset, select_sql)
    directory = File.join(exports_dir, batch_id.to_s, dataset)
    FileUtils.mkdir_p(directory)
    destination = File.join(directory, 'part-0.parquet').gsub("'", "''")
    database = DuckDB::Database.open
    connection = database.connect
    connection.query("COPY (#{select_sql}) TO '#{destination}' (FORMAT PARQUET)")
  ensure
    connection&.close
    database&.close
  end

  it 'stores every scenario metric column as a typed cell sharing one digest' do
    write_parquet('scenario_metrics', <<~SQL.squish)
      SELECT 'alien_rt_destroyed_12m' AS metric, 68 AS round_count, 0 AS kill_count,
             0.1::FLOAT AS kill_rate, 0.9411765::FLOAT AS win_rate
    SQL

    expect { service.call }.to change(AnalysisResult, :count).by(5)

    cells = AnalysisResult.where(batch_id: batch_id, model: 'scenario_metrics')
    expect(cells.pluck(:field)).to match_array(%w[metric round_count kill_count kill_rate win_rate])
    expect(cells.distinct.pluck(:digest)).to all(have_attributes(bytesize: 16))
    expect(cells.where(field: 'metric').pick(:text_value)).to eq('alien_rt_destroyed_12m')
    expect(cells.where(field: 'round_count').pick(:value)).to eq(68.0)
  end

  it 'uses the logical skill model and imports the user lookup fields' do
    write_parquet('users', "SELECT 7 AS id, 'name' AS nickname, '0:1:7' AS steam_id, 4.0::FLOAT AS skill, 9 AS wins,
                              3 AS losses, 0.75::DOUBLE AS win_ratio")
    write_parquet('skill_dl', 'SELECT 7 AS user_id, 27.5::FLOAT AS skill_dl')

    service.call

    expect(AnalysisResult.where(batch_id: batch_id, model: 'dl').pluck(:field)).to match_array(%w[user_id skill_dl])
    expect(AnalysisResult.rows_from(AnalysisResult.where(batch_id: batch_id, model: 'users')).first).to include(
      'id' => 7.0, 'steam_id' => '0:1:7', 'wins' => 9.0
    )
  end

  it 'replaces map-balance snapshots without touching historical batches' do
    write_parquet('map_balance', "SELECT 'ns_tram' AS map_name, 8 AS marine_wins, 12 AS alien_wins, 20 AS total_games,
                                  0.4::FLOAT AS marine_win_percentage, 0.6::FLOAT AS alien_win_percentage")

    service.call

    expect(AnalysisResult.current_snapshot.where(model: 'map_balance').count).to eq(6)
    expect(AnalysisResult.historical.where(batch_id: batch_id, model: 'map_balance')).to be_empty
  end

  it 'does not import raw round/log datasets' do
    write_parquet('rounds', "SELECT 1 AS id, 1 AS result, 'ns_tram' AS map_name, 'server' AS server_name,
                             now() AS start_time, now() AS end_time")

    expect { service.call }.to raise_error(AnalysisBatchImportService::Error, /No recognized analysis exports/)
    expect(AnalysisResult.count).to eq(0)
  end
end
