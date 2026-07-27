# frozen_string_literal: true

require 'rails_helper'

describe GithubReleaseAssetSyncJob do
  let(:job) { described_class.new }
  let(:logger) { instance_double(Logger, info: nil, error: nil) }

  before do
    allow(Rails).to receive(:logger).and_return(logger)
  end

  describe '#perform' do
    around do |example|
      Dir.mktmpdir('github_release_asset_sync_job_spec') do |tmp_dir|
        @tmp_dir = tmp_dir
        # The job must run against a temporary process-level root for isolation.
        original_files_root = ENV['FILES_ROOT']
        ENV['FILES_ROOT'] = tmp_dir
        example.run
      ensure
        ENV['FILES_ROOT'] = original_files_root
      end
    end

    it 'downloads assets for fetched tags and runs reconciliation for root directory' do
      root_directory = instance_double(Directory)
      destination_root = File.join(@tmp_dir, 'client')

      allow(job).to receive(:fetch_tags).with('ENSL/NS').and_return(%w[v1.0.0 v2.0.0])
      allow(job).to receive(:fetch_release_assets).with('ENSL/NS').and_return(
        'v1.0.0' => ['https://example.test/a.zip'],
        'v2.0.0' => ['https://example.test/b.zip', 'https://example.test/b.zip']
      )

      expect(job).to receive(:download_asset)
        .with(destination_root, 'https://example.test/a.zip', prefix: 'v1.0.0')
      expect(job).to receive(:download_asset)
        .with(destination_root, 'https://example.test/b.zip', prefix: 'v2.0.0')
        .once

      allow(Directory).to receive(:find_by).with(id: Directory::ROOT).and_return(root_directory)
      reconciliation_service = instance_double(DirectoryReconciliationService, call: StringIO.new('ok'))
      expect(DirectoryReconciliationService).to receive(:new).with(root_directory).and_return(reconciliation_service)

      job.perform
    end

    it 'uses provided repo option and skips reconciliation when root is missing' do
      allow(job).to receive(:fetch_tags).with('owner/repo').and_return([])
      allow(job).to receive(:fetch_release_assets).with('owner/repo').and_return({})
      allow(Directory).to receive(:find_by).with(id: Directory::ROOT).and_return(nil)

      expect(DirectoryReconciliationService).not_to receive(:new)

      job.perform('repo' => 'owner/repo')
    end

    it 'falls back to default repo when options are not a hash' do
      allow(job).to receive(:fetch_tags).with('ENSL/NS').and_return([])
      allow(job).to receive(:fetch_release_assets).with('ENSL/NS').and_return({})
      allow(Directory).to receive(:find_by).with(id: Directory::ROOT).and_return(nil)

      job.perform('invalid-options')
    end
  end

  describe '#fetch_tags' do
    it 'returns only present tag names from paginated responses' do
      allow(job).to receive(:github_paginated_get)
        .with('/repos/owner/repo/tags?per_page=100')
        .and_return([
                      { 'name' => 'v1.2.3' },
                      { 'name' => '' },
                      { 'name' => nil },
                      {}
                    ])

      expect(job.send(:fetch_tags, 'owner/repo')).to eq(['v1.2.3'])
    end
  end

  describe '#fetch_release_assets' do
    it 'groups asset URLs by tag and removes duplicates and blank entries' do
      allow(job).to receive(:github_paginated_get)
        .with('/repos/owner/repo/releases?per_page=100')
        .and_return([
                      {
                        'tag_name' => 'v1.0.0',
                        'assets' => [
                          { 'browser_download_url' => 'https://example.test/a.zip' },
                          { 'browser_download_url' => '' }
                        ]
                      },
                      {
                        'tag_name' => 'v1.0.0',
                        'assets' => [
                          { 'browser_download_url' => 'https://example.test/a.zip' },
                          { 'browser_download_url' => 'https://example.test/b.zip' }
                        ]
                      },
                      {
                        'tag_name' => '',
                        'assets' => [{ 'browser_download_url' => 'https://example.test/ignored.zip' }]
                      },
                      {
                        'tag_name' => 'v2.0.0',
                        'assets' => nil
                      }
                    ])

      expect(job.send(:fetch_release_assets, 'owner/repo')).to eq(
        'v1.0.0' => ['https://example.test/a.zip', 'https://example.test/b.zip']
      )
    end
  end

  describe '#github_paginated_get' do
    let(:connection) { instance_double(Faraday::Connection) }

    before do
      allow(job).to receive(:github_connection).and_return(connection)
    end

    it 'collects paginated array responses and follows rel=next links' do
      response_page_one = instance_double(
        Faraday::Response,
        success?: true,
        status: 200,
        body: [{ 'name' => 'one' }].to_json,
        headers: {
          'link' => '<https://api.github.com/repos/owner/repo/tags?per_page=100&page=2>; rel="next", ' \
                    '<https://api.github.com/repos/owner/repo/tags?per_page=100&page=2>; rel="last"'
        }
      )
      response_page_two = instance_double(
        Faraday::Response,
        success?: true,
        status: 200,
        body: [{ 'name' => 'two' }].to_json,
        headers: {}
      )

      expect(connection).to receive(:get)
        .with('/repos/owner/repo/tags?per_page=100')
        .and_yield(double(headers: {}))
        .and_return(response_page_one)
      expect(connection).to receive(:get)
        .with('https://api.github.com/repos/owner/repo/tags?per_page=100&page=2')
        .and_yield(double(headers: {}))
        .and_return(response_page_two)

      expect(job.send(:github_paginated_get, '/repos/owner/repo/tags?per_page=100')).to eq(
        [{ 'name' => 'one' }, { 'name' => 'two' }]
      )
    end

    it 'wraps non-array payloads into an array' do
      response = instance_double(
        Faraday::Response,
        success?: true,
        status: 200,
        body: { 'tag_name' => 'v1.0.0' }.to_json,
        headers: {}
      )

      expect(connection).to receive(:get)
        .with('/repos/owner/repo/releases/latest')
        .and_yield(double(headers: {}))
        .and_return(response)

      expect(job.send(:github_paginated_get, '/repos/owner/repo/releases/latest')).to eq(
        [{ 'tag_name' => 'v1.0.0' }]
      )
    end

    it 'raises when a github request fails' do
      response = instance_double(Faraday::Response, success?: false, status: 500, headers: {}, body: '{}')
      expect(connection).to receive(:get)
        .with('/repos/owner/repo/tags?per_page=100')
        .and_yield(double(headers: {}))
        .and_return(response)

      expect { job.send(:github_paginated_get, '/repos/owner/repo/tags?per_page=100') }
        .to raise_error(RuntimeError, 'GitHub request failed (500) for /repos/owner/repo/tags?per_page=100')
    end
  end

  describe '#next_link_from' do
    it 'extracts the next link from a Link header' do
      header = '<https://api.github.com/path?page=2>; rel="next", <https://api.github.com/path?page=5>; rel="last"'

      expect(job.send(:next_link_from, header)).to eq('https://api.github.com/path?page=2')
    end

    it 'returns nil when no next link is present' do
      expect(job.send(:next_link_from, nil)).to be_nil
      expect(job.send(:next_link_from, '<https://api.github.com/path?page=1>; rel="prev"')).to be_nil
    end
  end

  describe '#filename_for' do
    it 'builds prefixed, sanitized filenames from asset URLs' do
      expect(job.send(:filename_for, 'https://example.test/files/Build%20One.zip',
                      'V1 Beta')).to eq('v1_beta__Build One.zip')
    end

    it 'falls back to asset when URL has no basename' do
      expect(job.send(:filename_for, 'https://example.test', nil)).to eq('asset')
    end

    it 'falls back to prefixed asset for invalid URLs' do
      expect(job.send(:filename_for, 'http://%', 'Release 1')).to eq('release_1__asset')
    end
  end

  describe '#safe_name' do
    it 'normalizes to lowercase and replaces unsafe characters' do
      expect(job.send(:safe_name, 'Release 1/RC+Final')).to eq('release_1_rc_final')
    end
  end

  describe '#download_asset' do
    around do |example|
      Dir.mktmpdir('github_release_asset_sync_job_download_spec') do |tmp_dir|
        @tmp_dir = tmp_dir
        example.run
      end
    end

    it 'skips when a matching data_file record exists' do
      allow(job).to receive(:filename_for).and_return('v1__asset.zip')
      expect(DataFile).to receive(:exists?).with(name: 'v1__asset.zip').and_return(true)
      expect(Net::HTTP).not_to receive(:start)

      job.send(:download_asset, @tmp_dir, 'https://example.test/a.zip', prefix: 'v1')

      expect(logger).to have_received(:info).with(include('Skipping existing DB file v1__asset.zip'))
    end

    it 'skips when destination file already exists' do
      allow(job).to receive(:filename_for).and_return('v1__asset.zip')
      allow(DataFile).to receive(:exists?).with(name: 'v1__asset.zip').and_return(false)

      destination_path = File.join(@tmp_dir, 'v1__asset.zip')
      File.binwrite(destination_path, 'existing')

      expect(Net::HTTP).not_to receive(:start)

      job.send(:download_asset, @tmp_dir, 'https://example.test/a.zip', prefix: 'v1')

      expect(logger).to have_received(:info).with(include('Skipping existing file', destination_path))
    end

    it 'downloads and writes the asset when missing in DB and filesystem' do
      allow(job).to receive(:filename_for).and_return('v1__asset.zip')
      allow(DataFile).to receive(:exists?).with(name: 'v1__asset.zip').and_return(false)

      stub_request(:get, 'https://example.test/a.zip')
        .with(headers: { 'User-Agent' => described_class::USER_AGENT })
        .to_return(status: 200, body: 'binary-data')

      destination_path = File.join(@tmp_dir, 'v1__asset.zip')
      job.send(:download_asset, @tmp_dir, 'https://example.test/a.zip', prefix: 'v1')

      expect(File.binread(destination_path)).to eq('binary-data')
      expect(logger).to have_received(:info).with(include('Downloaded https://example.test/a.zip'))
    end

    it 'logs errors when download fails' do
      allow(job).to receive(:filename_for).and_return('v1__asset.zip')
      allow(DataFile).to receive(:exists?).with(name: 'v1__asset.zip').and_return(false)

      stub_request(:get, 'https://example.test/a.zip').to_timeout

      job.send(:download_asset, @tmp_dir, 'https://example.test/a.zip', prefix: 'v1')

      expect(logger).to have_received(:error)
        .with(match(%r{Failed to download https://example\.test/a\.zip: (timeout|execution expired)}))
    end
  end
end
