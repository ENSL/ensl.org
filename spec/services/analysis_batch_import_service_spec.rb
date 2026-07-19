# frozen_string_literal: true

require 'rails_helper'

RSpec.describe AnalysisBatchImportService do
  let(:batch_id) { 42 }
  let(:exports_dir) { Dir.mktmpdir('analysis-export-spec') }
  let(:service) { described_class.new(batch_id, exports_dir: exports_dir) }

  after do
    FileUtils.remove_entry(exports_dir) if File.directory?(exports_dir)
  end

  describe '#call' do
    it 'returns 0 when there are no rows to import' do
      allow(service).to receive(:read_rows).and_return([])
      allow(AnalysisResult).to receive(:upsert_all)

      expect(service.call).to eq(0)
      expect(AnalysisResult).not_to have_received(:upsert_all)
    end

    it 'upserts all rows in slices and returns imported count' do
      rows = Array.new(1_001) { |i| { steamid: "s#{i}", model: 'os', metric: 'skill', value: i } }
      allow(service).to receive(:read_rows).and_return(rows)
      allow(AnalysisResult).to receive(:upsert_all)

      expect(service.call).to eq(1_001)
      expect(AnalysisResult).to have_received(:upsert_all).twice
      expect(AnalysisResult).to have_received(:upsert_all).with(rows.first(1_000), record_timestamps: false)
      expect(AnalysisResult).to have_received(:upsert_all).with(rows.last(1), record_timestamps: false)
    end
  end

  describe '#read_rows' do
    let(:database) { instance_double('DuckDB::Database') }
    let(:connection) { instance_double('DuckDB::Connection') }

    before do
      allow(DuckDB::Database).to receive(:open).and_return(database)
      allow(database).to receive(:connect).and_return(connection)
      allow(connection).to receive(:close)
      allow(database).to receive(:close)
    end

    it 'returns flattened rows from all sources and closes resources' do
      allow(service).to receive(:read_legacy_rows).and_return([{ a: 1 }])
      allow(service).to receive(:read_skill_model_rows).and_return([{ b: 2 }])
      allow(service).to receive(:read_player_stat_rows).and_return([])
      allow(service).to receive(:read_map_balance_rows).and_return([{ c: 3 }])
      allow(service).to receive(:read_time_of_week_rows).and_return([])

      rows = service.send(:read_rows)

      expect(rows).to eq([{ a: 1 }, { b: 2 }, { c: 3 }])
      expect(connection).to have_received(:close)
      expect(database).to have_received(:close)
    end

    it 'raises when no recognized exports are present and still closes resources' do
      allow(service).to receive(:read_legacy_rows).and_return([])
      allow(service).to receive(:read_skill_model_rows).and_return([])
      allow(service).to receive(:read_player_stat_rows).and_return([])
      allow(service).to receive(:read_map_balance_rows).and_return([])
      allow(service).to receive(:read_time_of_week_rows).and_return([])

      expect { service.send(:read_rows) }.to raise_error(AnalysisBatchImportService::Error, /No recognized exports/)
      expect(connection).to have_received(:close)
      expect(database).to have_received(:close)
    end
  end

  describe '#read_legacy_rows' do
    let(:connection) { instance_double('DuckDB::Connection') }
    let(:imported_at) { Time.current }

    it 'reads from analysis_results when present' do
      allow(service).to receive(:existing_glob).with('analysis_results').and_return('/tmp/a/*.parquet')
      allow(connection).to receive(:query).and_return([['steam', 'os', 'skill', 12.5, nil]])

      rows = service.send(:read_legacy_rows, connection, imported_at)

      expect(rows.first[:steamid]).to eq('steam')
      expect(rows.first[:model]).to eq('os')
    end

    it 'falls back to metrics when analysis_results is missing' do
      allow(service).to receive(:existing_glob).with('analysis_results').and_return(nil)
      allow(service).to receive(:existing_glob).with('metrics').and_return('/tmp/m/*.parquet')
      allow(connection).to receive(:query).and_return([[nil, 'agg', 'value', 1.25, 2]])

      rows = service.send(:read_legacy_rows, connection, imported_at)

      expect(rows.first[:steamid]).to eq(AnalysisResult::NO_STEAMID)
      expect(rows.first[:model]).to eq('agg')
      expect(rows.first[:milestone]).to eq(2)
    end

    it 'returns empty array when neither legacy source exists' do
      allow(service).to receive(:existing_glob).with('analysis_results').and_return(nil)
      allow(service).to receive(:existing_glob).with('metrics').and_return(nil)

      expect(service.send(:read_legacy_rows, connection, imported_at)).to eq([])
    end
  end

  describe '#read_skill_model_rows' do
    let(:connection) { instance_double('DuckDB::Connection') }

    it 'returns empty array when users export is missing' do
      allow(service).to receive(:existing_glob).with('users').and_return(nil)

      expect(service.send(:read_skill_model_rows, connection, Time.current)).to eq([])
    end

    it 'maps joined rows for available skill model exports' do
      imported_at = Time.current
      allow(service).to receive(:existing_glob) do |subdir|
        case subdir
        when 'users' then '/tmp/users/*.parquet'
        when 'skill_os' then '/tmp/skill_os/*.parquet'
        end
      end
      allow(connection).to receive(:query).and_return([['0:1:1', 31.25]])

      rows = service.send(:read_skill_model_rows, connection, imported_at)

      metrics = rows.select { |r| r[:model] == 'os' }.map { |r| r[:metric] }
      expect(metrics).to include('mu', 'sigma', 'skill')
      expect(rows.all? { |r| r[:steamid] == '0:1:1' }).to be(true)
    end
  end

  describe '#read_player_stat_rows' do
    let(:connection) { instance_double('DuckDB::Connection') }

    it 'returns empty array when users export is missing' do
      allow(service).to receive(:existing_glob).with('users').and_return(nil)

      expect(service.send(:read_player_stat_rows, connection, Time.current)).to eq([])
    end

    it 'builds rows for each configured player stat metric' do
      imported_at = Time.current
      allow(service).to receive(:existing_glob).with('users').and_return('/tmp/users/*.parquet')
      allow(connection).to receive(:query).and_return([['0:1:2', 9]])

      rows = service.send(:read_player_stat_rows, connection, imported_at)

      expect(rows.map { |r| r[:metric] }).to include('wins', 'losses', 'win_ratio')
      expect(rows.map { |r| r[:model] }.uniq).to eq(['player_stats'])
    end
  end

  describe '#read_map_balance_rows' do
    let(:connection) { instance_double('DuckDB::Connection') }

    it 'returns empty array when map_balance export is missing' do
      allow(service).to receive(:existing_glob).with('map_balance').and_return(nil)

      expect(service.send(:read_map_balance_rows, connection, Time.current)).to eq([])
    end

    it 'builds current-snapshot rows for map metrics' do
      imported_at = Time.current
      allow(service).to receive(:existing_glob).with('map_balance').and_return('/tmp/map_balance/*.parquet')
      allow(connection).to receive(:query).and_return([['ns2_tram', 0.6]])

      rows = service.send(:read_map_balance_rows, connection, imported_at)

      expect(rows.map { |r| r[:model] }.uniq).to eq(['map_balance'])
      expect(rows.map { |r| r[:batch_id] }.uniq).to eq([AnalysisResult::CURRENT_SNAPSHOT_BATCH_ID])
      expect(rows.size).to eq(AnalysisBatchImportService::MAP_BALANCE_METRICS.size)
    end
  end

  describe '#read_time_of_week_rows' do
    let(:connection) { instance_double('DuckDB::Connection') }

    it 'returns empty array when time_of_week export is missing' do
      allow(service).to receive(:existing_glob).with('time_of_week').and_return(nil)

      expect(service.send(:read_time_of_week_rows, connection, Time.current)).to eq([])
    end

    it 'builds current snapshot rows from day/hour aggregates' do
      imported_at = Time.current
      allow(service).to receive(:existing_glob).with('time_of_week').and_return('/tmp/time_of_week/*.parquet')
      allow(connection).to receive(:query).and_return([[3, 17, 121]])

      rows = service.send(:read_time_of_week_rows, connection, imported_at)

      expect(rows.first[:steamid]).to eq('3')
      expect(rows.first[:milestone]).to eq(17)
      expect(rows.first[:metric]).to eq('round_count')
      expect(rows.first[:batch_id]).to eq(AnalysisResult::CURRENT_SNAPSHOT_BATCH_ID)
    end
  end

  describe '#existing_glob' do
    it 'returns glob when parquet files exist in the subdir' do
      dir = File.join(exports_dir, batch_id.to_s, 'metrics')
      FileUtils.mkdir_p(dir)
      File.write(File.join(dir, 'part-1.parquet'), 'content')

      glob = service.send(:existing_glob, 'metrics')

      expect(glob).to eq(File.join(dir, '*.parquet'))
    end

    it 'returns nil when subdir is absent or has no parquet files' do
      expect(service.send(:existing_glob, 'missing')).to be_nil

      empty_dir = File.join(exports_dir, batch_id.to_s, 'empty')
      FileUtils.mkdir_p(empty_dir)
      expect(service.send(:existing_glob, 'empty')).to be_nil
    end

    it 'raises when resolved path escapes exports dir' do
      allow(service).to receive(:batch_dir).and_return('/tmp/not-under-root/42')

      expect { service.send(:existing_glob, 'metrics') }.to raise_error(AnalysisBatchImportService::Error,
                                                                        /escapes exports dir/)
    end
  end
end
