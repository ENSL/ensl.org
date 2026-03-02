# frozen_string_literal: true

require 'rails_helper'

describe DataFileSyncJob do
  let(:job) { described_class.new }
  let(:ftp) { instance_double(Net::FTP) }
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

  around do |example|
    Dir.mktmpdir('data_file_sync_job_spec') do |tmp_dir|
      @tmp_dir = tmp_dir
      example.run
    end
  end

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

    job.send(:sync_server, server_config)
  end
end
