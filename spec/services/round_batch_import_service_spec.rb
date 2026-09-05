# frozen_string_literal: true

require 'rails_helper'

RSpec.describe RoundBatchImportService do
  let(:batch_id) { 7 }
  let(:exports_dir) { Dir.mktmpdir('round-export-spec') }
  let(:service) { described_class.new(batch_id, exports_dir: exports_dir) }

  after do
    FileUtils.remove_entry(exports_dir) if File.directory?(exports_dir)
  end

  describe '#call' do
    it 'raises when nothing was imported' do
      allow(service).to receive_messages(read_log_files: [], read_rounds: [], read_rounders: [], read_log_lines: [])

      expect { service.call }.to raise_error(RoundBatchImportService::Error, /No recognized exports/)
    end

    it 'upserts each table and returns row counts' do
      allow(service).to receive(:read_log_files).and_return([{ sha256: 'abc', filename: 'a.log',
                                                                 server_name: 's', created_at: Time.current }])
      allow(service).to receive(:read_rounds).and_return([{ server_name: 's', start_time: Time.current,
                                                              end_time: Time.current, map_name: 'ns_eclipse',
                                                              result: 1 }])
      allow(service).to receive(:read_rounders).and_return([{ round_id: 1, steamid: '1:2:3', team: 1, share: 1.0 }])
      allow(service).to receive(:read_log_lines).and_return([])
      allow(LogFile).to receive(:upsert_all)
      allow(Round).to receive(:upsert_all)
      allow(Rounder).to receive(:upsert_all)

      counts = service.call

      expect(counts).to eq(log_files: 1, rounds: 1, rounders: 1, log_lines: 0)
      expect(LogFile).to have_received(:upsert_all).with(anything, record_timestamps: false)
      expect(Round).to have_received(:upsert_all).with(anything, record_timestamps: false)
      expect(Rounder).to have_received(:upsert_all).with(anything, record_timestamps: false)
    end
  end

  describe '#read_log_files' do
    let(:connection) { instance_double('DuckDB::Connection') }

    it 'returns empty array when log_files export is missing' do
      allow(service).to receive(:existing_glob).with('log_files').and_return(nil)

      expect(service.send(:read_log_files, connection)).to eq([])
    end

    it 'maps parquet rows to LogFile attributes' do
      allow(service).to receive(:existing_glob).with('log_files').and_return('/tmp/log_files/*.parquet')
      allow(connection).to receive(:query).and_return([['sha', 'a.log', 'server one', Time.current]])

      rows = service.send(:read_log_files, connection)

      expect(rows.first).to include(sha256: 'sha', filename: 'a.log', server_name: 'server one')
    end
  end

  describe '#read_rounds' do
    let(:connection) { instance_double('DuckDB::Connection') }

    it 'returns empty array when rounds export is missing' do
      allow(service).to receive(:existing_glob).with('rounds').and_return(nil)

      expect(service.send(:read_rounds, connection)).to eq([])
    end

    it 'maps parquet rows to Round attributes' do
      allow(service).to receive(:existing_glob).with('rounds').and_return('/tmp/rounds/*.parquet')
      allow(connection).to receive(:query).and_return([['server one', Time.current, Time.current, 'ns_eclipse', 1]])

      rows = service.send(:read_rounds, connection)

      expect(rows.first).to include(server_name: 'server one', map_name: 'ns_eclipse', result: 1)
    end
  end

  describe '#read_rounders' do
    let(:connection) { instance_double('DuckDB::Connection') }

    it 'returns empty array when any sibling export is missing' do
      allow(service).to receive(:existing_glob).with('round_users').and_return('/tmp/round_users/*.parquet')
      allow(service).to receive(:existing_glob).with('rounds').and_return(nil)
      allow(service).to receive(:existing_glob).with('users').and_return('/tmp/users/*.parquet')

      expect(service.send(:read_rounders, connection)).to eq([])
    end

    it 'resolves the round via server_name/start_time and skips unresolved rounds' do
      round = Round.create!(server_name: 'server one', start_time: Time.current.change(usec: 0))
      allow(service).to receive(:existing_glob).and_return('/tmp/glob/*.parquet')
      allow(connection).to receive(:query).and_return(
        [
          [round.server_name, round.start_time, '1:2:3', 1, 0.75],
          ['unknown server', Time.current, '4:5:6', -1, 0.5]
        ]
      )

      rows = service.send(:read_rounders, connection)

      expect(rows).to contain_exactly({ round_id: round.id, steamid: '1:2:3', team: 1, share: 0.75 })
    end
  end

  describe '#read_log_lines' do
    let(:connection) { instance_double('DuckDB::Connection') }

    it 'returns empty array unless rounds, log_files, and users are all present' do
      allow(service).to receive(:existing_glob).with('log_lines').and_return('/tmp/log_lines/*.parquet')
      allow(service).to receive(:existing_glob).with('rounds').and_return('/tmp/rounds/*.parquet')
      allow(service).to receive(:existing_glob).with('log_files').and_return(nil)
      allow(service).to receive(:existing_glob).with('users').and_return('/tmp/users/*.parquet')

      expect(service.send(:read_log_lines, connection)).to eq([])
    end

    it 'resolves round_id/log_file_id by natural key and computes a line digest' do
      log_file = LogFile.create!(sha256: 'sha', filename: 'a.log')
      round = Round.create!(server_name: 'server one', start_time: Time.current.change(usec: 0))
      allow(service).to receive(:existing_glob).and_return('/tmp/glob/*.parquet')
      allow(connection).to receive(:query).and_return(
        [
          ['raw line text', 'kill', 'p1', 'p2', 'p3', round.server_name, round.start_time, log_file.sha256,
           '1:2:3', '4:5:6', 'server one', Time.current]
        ]
      )

      rows = service.send(:read_log_lines, connection)

      expect(rows.first).to include(
        log_file_id: log_file.id,
        round_id: round.id,
        raw_text: 'raw line text',
        actor_steamid: '1:2:3',
        target_steamid: '4:5:6',
        line_digest: Digest::SHA256.hexdigest('raw line text')
      )
    end

    it 'skips rows whose log_file cannot be resolved' do
      allow(service).to receive(:existing_glob).and_return('/tmp/glob/*.parquet')
      allow(connection).to receive(:query).and_return(
        [['raw line text', 'kill', nil, nil, nil, nil, nil, 'missing-sha', nil, nil, 'server one', Time.current]]
      )

      expect(service.send(:read_log_lines, connection)).to eq([])
    end
  end

  describe '#existing_glob' do
    it 'returns glob when parquet files exist in the subdir' do
      dir = File.join(exports_dir, batch_id.to_s, 'rounds')
      FileUtils.mkdir_p(dir)
      File.write(File.join(dir, 'part-1.parquet'), 'content')

      expect(service.send(:existing_glob, 'rounds')).to eq(File.join(dir, '*.parquet'))
    end

    it 'returns nil when subdir is absent or empty' do
      expect(service.send(:existing_glob, 'missing')).to be_nil
    end

    it 'raises when resolved path escapes exports dir' do
      allow(service).to receive(:batch_dir).and_return('/tmp/not-under-root/42')

      expect { service.send(:existing_glob, 'rounds') }.to raise_error(RoundBatchImportService::Error, /escapes/)
    end
  end
end
