# frozen_string_literal: true

require 'rails_helper'

describe DataFileSyncJob do
  let(:job) { described_class.new }
  let(:ftp) { instance_double(Net::FTP) }
  let(:logger) { instance_double(Logger, info: nil, error: nil) }
  let(:server_config) do
    {
      nickname: 'alpha',
      host: 'ftp.example.test',
      username: 'user',
      password: 'pass',
      passive: true,
      dirs: ['/logs']
    }
  end

  before do
    allow(Rails).to receive(:logger).and_return(logger)
  end

  around do |example|
    Dir.mktmpdir('data_file_sync_job_spec') do |tmp_dir|
      @tmp_dir = tmp_dir
      example.run
    end
  end

  describe '#perform' do
    it 'syncs configured servers and always runs directory reconciliation' do
      root_directory = instance_double(Directory)
      reconciliation_service = instance_double(DirectoryReconciliationService, call: StringIO.new('ok'))

      allow(job).to receive(:load_server_configs).and_return([server_config])
      expect(job).to receive(:sync_server).with(server_config)
      allow(Directory).to receive(:find_by).with(id: Directory::ROOT).and_return(root_directory)
      expect(DirectoryReconciliationService).to receive(:new).with(root_directory).and_return(reconciliation_service)

      job.perform
    end

    it 'skips download sync when no server configs are available and still reconciles directories' do
      root_directory = instance_double(Directory)
      reconciliation_service = instance_double(DirectoryReconciliationService, call: StringIO.new('ok'))

      allow(job).to receive(:load_server_configs).and_return([])
      expect(job).not_to receive(:sync_server)
      allow(Directory).to receive(:find_by).with(id: Directory::ROOT).and_return(root_directory)
      allow(DirectoryReconciliationService).to receive(:new).with(root_directory).and_return(reconciliation_service)
      expect(logger).to receive(:info).with('[DataFileSyncJob] No server config entries found; skipping download sync')

      job.perform
    end
  end

  describe '#load_server_configs' do
    it 'returns an empty array when the config file is missing' do
      allow(File).to receive(:exist?).and_call_original
      allow(File).to receive(:exist?).with(described_class::CONFIG_PATH).and_return(false)

      expect(logger).to receive(:error).with("[DataFileSyncJob] Missing config file: #{described_class::CONFIG_PATH}")

      expect(job.send(:load_server_configs)).to eq([])
    end

    it 'returns an empty array when the config file contains invalid JSON' do
      allow(File).to receive(:exist?).and_call_original
      allow(File).to receive(:read).and_call_original
      allow(File).to receive(:exist?).with(described_class::CONFIG_PATH).and_return(true)
      allow(File).to receive(:read).with(described_class::CONFIG_PATH.to_s).and_return('{invalid-json')

      expect(logger).to receive(:error).with(/\[DataFileSyncJob\] Invalid JSON config:/)

      expect(job.send(:load_server_configs)).to eq([])
    end

    it 'resolves env values and filters invalid server and dir entries' do
      allow(File).to receive(:exist?).and_call_original
      allow(File).to receive(:read).and_call_original
      allow(File).to receive(:exist?).with(described_class::CONFIG_PATH).and_return(true)
      allow(File).to receive(:read).with(described_class::CONFIG_PATH.to_s).and_return(
        {
          'servers' => [
            {
              'nickname' => ' Alpha Server ',
              'host' => 'ftp.example.test',
              'username' => 'deploy',
              'password' => 'env:FTP_PASSWORD',
              'passive' => false,
              'dirs' => ['/logs', { 'remote' => '/demos' }, '', {}, nil]
            },
            {
              'nickname' => 'Missing Host',
              'username' => 'deploy',
              'password' => 'secret'
            },
            'not-a-hash'
          ]
        }.to_json
      )
      allow(ENV).to receive(:[]).and_call_original
      allow(ENV).to receive(:[]).with('FTP_PASSWORD').and_return('secret')

      expect(logger).to receive(:error)
        .with('[DataFileSyncJob] Invalid server config entry (nickname/host/username/password required); skipping')
        .twice

      expect(job.send(:load_server_configs)).to eq([
                                                     {
                                                       nickname: 'alpha_server',
                                                       host: 'ftp.example.test',
                                                       username: 'deploy',
                                                       password: 'secret',
                                                       passive: false,
                                                       dirs: ['/logs', '/demos']
                                                     }
                                                   ])
    end
  end

  describe '#sync_server' do
    it 'downloads using destination selected by DataFile sync planner' do
      remote_mtime = Time.utc(2026, 1, 3, 0, 0, 0)
      destination_path = File.join(@tmp_dir, 'logs', 'alpha', '2026', 'monthly_2026_1.log')

      allow(Net::FTP).to receive(:open).and_yield(ftp)
      allow(ftp).to receive(:passive=)
      allow(ftp).to receive(:pwd).and_return('/')
      allow(ftp).to receive(:chdir)
      allow(ftp).to receive(:nlst).and_return(['monthly.log'])
      allow(ftp).to receive(:size).with('monthly.log').and_return(2048)
      allow(ftp).to receive(:mtime).with('monthly.log').and_return(remote_mtime)

      expect(DataFile).to receive(:sync_download_plan)
        .with(nickname: 'alpha', filename: 'monthly.log', remote_size: 2048, remote_mtime: remote_mtime)
        .and_return({ download: true, destination_path: destination_path, reason: :download })

      allow(ftp).to receive(:getbinaryfile) { |_remote, local| File.binwrite(local, 'new-month') }

      job.send(:sync_server, server_config)

      expect(File.binread(destination_path)).to eq('new-month')
    end

    it 'skips FTP download when DataFile sync planner marks file up-to-date' do
      remote_mtime = Time.utc(2026, 1, 3, 0, 0, 0)
      destination_path = File.join(@tmp_dir, 'logs', 'alpha', '2026', 'monthly.log')

      allow(Net::FTP).to receive(:open).and_yield(ftp)
      allow(ftp).to receive(:passive=)
      allow(ftp).to receive(:pwd).and_return('/')
      allow(ftp).to receive(:chdir)
      allow(ftp).to receive(:nlst).and_return(['monthly.log'])
      allow(ftp).to receive(:size).with('monthly.log').and_return(2048)
      allow(ftp).to receive(:mtime).with('monthly.log').and_return(remote_mtime)

      allow(DataFile).to receive(:sync_download_plan)
        .and_return({ download: false, destination_path: destination_path, reason: :up_to_date })

      expect(ftp).not_to receive(:getbinaryfile)
      expect(logger).not_to receive(:error).with(%r{Failed syncing alpha:/logs})

      job.send(:sync_server, server_config)
    end

    it 'coerces TimeWithZone values before File.utime' do
      remote_mtime = Time.zone.parse('2026-03-01 12:34:56 UTC')
      destination_path = File.join(@tmp_dir, 'logs', 'alpha', '2026', 'monthly.log')

      allow(Net::FTP).to receive(:open).and_yield(ftp)
      allow(ftp).to receive(:passive=)
      allow(ftp).to receive(:pwd).and_return('/')
      allow(ftp).to receive(:chdir)
      allow(ftp).to receive(:nlst).and_return(['monthly.log'])
      allow(ftp).to receive(:size).with('monthly.log').and_return(2048)
      allow(ftp).to receive(:mtime).with('monthly.log').and_return(remote_mtime)

      allow(DataFile).to receive(:sync_download_plan)
        .and_return({ download: true, destination_path: destination_path, reason: :download })

      allow(ftp).to receive(:getbinaryfile) { |_remote, local| File.binwrite(local, 'new-month') }
      expect(File).to receive(:utime).with(kind_of(Time), kind_of(Time), destination_path).and_call_original

      job.send(:sync_server, server_config)
    end

    it 'skips servers without any configured directories' do
      expect(Net::FTP).not_to receive(:open)
      expect(logger).to receive(:info).with('[DataFileSyncJob] No dirs configured for alpha; skipping server')

      job.send(:sync_server, server_config.merge(dirs: []))
    end

    it 'ignores planner-less files and tolerates missing size and mtime metadata' do
      allow(Net::FTP).to receive(:open).and_yield(ftp)
      allow(ftp).to receive(:passive=)
      allow(ftp).to receive(:pwd).and_return('/')
      allow(ftp).to receive(:chdir)
      allow(ftp).to receive(:nlst).and_return(['.', '..', 'monthly.log'])
      allow(ftp).to receive(:size).with('monthly.log').and_raise(Net::FTPPermError)
      allow(ftp).to receive(:mtime).with('monthly.log').and_raise(Net::FTPPermError)

      expect(DataFile).to receive(:sync_download_plan)
        .with(nickname: 'alpha', filename: 'monthly.log', remote_size: nil, remote_mtime: nil)
        .and_return(nil)
      expect(ftp).not_to receive(:getbinaryfile)

      job.send(:sync_server, server_config)
    end

    it 'logs per-directory sync failures and restores the original FTP directory' do
      allow(Net::FTP).to receive(:open).and_yield(ftp)
      allow(ftp).to receive(:passive=)
      allow(ftp).to receive(:pwd).and_return('/')
      expect(ftp).to receive(:chdir).with('/logs').ordered.and_raise(StandardError, 'bad dir')
      expect(logger).to receive(:error).with('[DataFileSyncJob] Failed syncing alpha:/logs (bad dir)')
      expect(ftp).to receive(:chdir).with('/').ordered

      job.send(:sync_server, server_config)
    end

    it 'logs FTP connection failures for the server' do
      allow(Net::FTP).to receive(:open).and_raise(StandardError, 'connection refused')

      expect(logger).to receive(:error).with('[DataFileSyncJob] Failed to sync server alpha: connection refused')

      job.send(:sync_server, server_config)
    end
  end

  describe '#run_directory_reconciliation' do
    it 'logs and returns when the root directory cannot be found' do
      allow(Directory).to receive(:find_by).with(id: Directory::ROOT).and_return(nil)
      expect(DirectoryReconciliationService).not_to receive(:new)
      expect(logger).to receive(:error)
        .with('[DataFileSyncJob] Failed to run DirectoryReconciliationService: root directory not found')

      job.send(:run_directory_reconciliation)
    end

    it 'logs reconciliation failures' do
      root_directory = instance_double(Directory)
      reconciliation_service = instance_double(DirectoryReconciliationService)

      allow(Directory).to receive(:find_by).with(id: Directory::ROOT).and_return(root_directory)
      allow(DirectoryReconciliationService).to receive(:new).with(root_directory).and_return(reconciliation_service)
      allow(reconciliation_service).to receive(:call).and_raise(StandardError, 'reconcile failed')
      expect(logger).to receive(:error).with('[DataFileSyncJob] Directory reconciliation failed: reconcile failed')

      job.send(:run_directory_reconciliation)
    end
  end
end
