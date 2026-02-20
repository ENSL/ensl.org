# frozen_string_literal: true

require 'cgi'
require 'fileutils'
require 'json'
require 'net/ftp'
require 'open-uri'

class DataFileSyncJob
  include Sidekiq::Job

  sidekiq_options queue: :default, retry: 5

  DEFAULT_REPO = 'ENSL/NS'
  GITHUB_API_BASE = 'https://api.github.com'
  USER_AGENT = 'ensl-sidekiq-data-file-sync'
  DEMO_FTP = {
    host: ENV['DEMO_FTP_HOST'],
    username: ENV['DEMO_FTP_USERNAME'],
    password: ENV['DEMO_FTP_PASSWORD'],
    directory: ENV.fetch('DEMO_FTP_DIRECTORY', '/'),
    enabled: false
  }.freeze

  def perform(options = {})
    options = normalize_options(options)
    client_root = File.join(files_root, 'client')
    demo_root = File.join(files_root, 'demos', 'sputnik')
    FileUtils.mkdir_p(client_root)
    FileUtils.mkdir_p(demo_root)

    sync_github_release_assets(client_root, options[:repo])

    if options[:enable_demo_downloader]
      sync_ftp_demos(demo_root, options[:demo_ftp])
    else
      Rails.logger.info('[DataFileSyncJob] Demo downloader is disabled; skipping demo sync')
    end
  ensure
    run_directory_reconciliation
  end

  private

  def normalize_options(options)
    opts = options.is_a?(Hash) ? options : {}

    {
      repo: opts['repo'].presence || opts[:repo].presence || DEFAULT_REPO,
      demo_ftp: DEMO_FTP.merge(opts['demo_ftp'] || opts[:demo_ftp] || {}),
      enable_demo_downloader: ActiveModel::Type::Boolean.new.cast(opts['enable_demo_downloader'] || opts[:enable_demo_downloader] || DEMO_FTP[:enabled])
    }
  end

  def files_root
    ENV['FILES_ROOT'].presence || File.join(Rails.root, 'public', 'files')
  end

  def sync_github_release_assets(destination_root, repo)
    tags = fetch_tags(repo)
    release_assets = fetch_release_assets(repo)

    tags.each do |tag|
      release_assets.fetch(tag, []).uniq.each do |asset_url|
        download_asset(destination_root, asset_url, prefix: tag)
      end
    end
  end

  def sync_ftp_demos(destination_root, ftp_config)
    if ftp_config[:host].blank? || ftp_config[:username].blank? || ftp_config[:password].blank?
      Rails.logger.error('[DataFileSyncJob] Demo FTP config missing host/username/password; skipping demo sync')
      return
    end

    Net::FTP.open(ftp_config[:host], ftp_config[:username], ftp_config[:password]) do |ftp|
      ftp.passive = true
      ftp.chdir(ftp_config[:directory])
      ftp.nlst.grep(/\.(dem|gz)\z/i).each do |filename|
        download_ftp_asset(destination_root, ftp, filename)
      end
    end
  rescue StandardError => e
    Rails.logger.error("[DataFileSyncJob] FTP demo sync failed: #{e.message}")
  end

  def fetch_tags(repo)
    github_paginated_get("/repos/#{repo}/tags?per_page=100").filter_map { |tag| tag['name'].presence }
  end

  def fetch_release_assets(repo)
    assets_by_tag = Hash.new { |hash, key| hash[key] = [] }

    github_paginated_get("/repos/#{repo}/releases?per_page=100").each do |release|
      tag = release['tag_name'].to_s
      next if tag.blank?

      Array(release['assets']).each do |asset|
        url = asset['browser_download_url'].to_s
        assets_by_tag[tag] << url if url.present?
      end
    end

    assets_by_tag.transform_values(&:uniq)
  end

  def github_paginated_get(path)
    results = []
    next_url = path

    while next_url.present?
      response = github_connection.get(next_url) do |request|
        request.headers['Accept'] = 'application/vnd.github+json'
        request.headers['User-Agent'] = USER_AGENT
      end

      raise "GitHub request failed (#{response.status}) for #{next_url}" unless response.success?

      body = JSON.parse(response.body)
      body = [body] unless body.is_a?(Array)
      results.concat(body)

      next_url = next_link_from(response.headers['link'])
    end

    results
  end

  def next_link_from(link_header)
    return nil if link_header.blank?

    next_part = link_header.split(',').map(&:strip).find { |segment| segment.include?('rel="next"') }
    return nil unless next_part

    next_part[/<([^>]+)>/, 1]
  end

  def github_connection
    @github_connection ||= Faraday.new(url: GITHUB_API_BASE) do |connection|
      connection.options.open_timeout = 20
      connection.options.timeout = 120
      connection.adapter(Faraday.default_adapter)
    end
  end

  def download_asset(destination_root, asset_url, prefix: nil)
    filename = filename_for(asset_url, prefix)
    destination_path = File.join(destination_root, filename)

    if File.exist?(destination_path)
      Rails.logger.info("[DataFileSyncJob] Skipping existing file #{destination_path}")
      return
    end

    URI.open(asset_url, 'User-Agent' => USER_AGENT, open_timeout: 20, read_timeout: 120) do |stream|
      File.open(destination_path, 'wb') do |file|
        IO.copy_stream(stream, file)
      end
    end

    Rails.logger.info("[DataFileSyncJob] Downloaded #{asset_url} -> #{destination_path}")
  rescue StandardError => e
    Rails.logger.error("[DataFileSyncJob] Failed to download #{asset_url}: #{e.message}")
  end

  def download_ftp_asset(destination_root, ftp, filename)
    destination_path = File.join(destination_root, File.basename(filename))
    remote_size = begin
      ftp.size(filename)
    rescue StandardError
      nil
    end
    remote_mtime = begin
      ftp.mtime(filename)
    rescue StandardError
      nil
    end

    unless should_download_ftp_file?(destination_path, remote_size, remote_mtime)
      Rails.logger.info("[DataFileSyncJob] Skipping up-to-date file #{destination_path}")
      return
    end

    ftp.getbinaryfile(filename, destination_path)
    File.utime(Time.now, remote_mtime, destination_path) if remote_mtime
    Rails.logger.info("[DataFileSyncJob] Downloaded FTP asset #{filename} -> #{destination_path}")
  rescue StandardError => e
    Rails.logger.error("[DataFileSyncJob] Failed to download FTP asset #{filename}: #{e.message}")
  end

  def should_download_ftp_file?(destination_path, remote_size, remote_mtime)
    return true unless File.exist?(destination_path)

    local_size = File.size(destination_path)
    local_mtime = File.mtime(destination_path)

    return true if remote_size && local_size != remote_size
    return true if remote_mtime && local_mtime < remote_mtime

    false
  end

  def filename_for(asset_url, prefix)
    basename = File.basename(URI.parse(asset_url).path.to_s)
    basename = CGI.unescape(basename)
    basename = 'asset' if basename.blank?

    return basename if prefix.blank?

    "#{safe_name(prefix)}__#{basename}"
  rescue URI::InvalidURIError
    prefix.blank? ? 'asset' : "#{safe_name(prefix)}__asset"
  end

  def run_directory_reconciliation
    root_directory = Directory.find_by(id: Directory::ROOT)
    unless root_directory
      Rails.logger.error('[DataFileSyncJob] Failed to run DirectoryReconciliationService: root directory not found')
      return
    end

    operation_log = DirectoryReconciliationService.new(root_directory).call
    Rails.logger.info("[DataFileSyncJob] Directory reconciliation completed\n#{operation_log.string}")
  rescue StandardError => e
    Rails.logger.error("[DataFileSyncJob] Directory reconciliation failed: #{e.message}")
  end

  def safe_name(value)
    value.to_s.gsub(%r{[\\/]}, '_')
  end
end
