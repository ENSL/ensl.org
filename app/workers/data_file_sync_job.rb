# frozen_string_literal: true

require 'fileutils'
require 'json'
require 'net/ftp'

class DataFileSyncJob
  include Sidekiq::Job

  sidekiq_options queue: :default, retry: 5

  CONFIG_PATH = Rails.root.join('config', 'data_file_sync_servers.json')

  def perform(_options = {})
    server_configs = load_server_configs

    if server_configs.blank?
      Rails.logger.info('[DataFileSyncJob] No server config entries found; skipping download sync')
      return
    end

    server_configs.each do |server_config|
      sync_server(server_config)
    end
  ensure
    run_directory_reconciliation
  end

  private

  def load_server_configs
    unless File.exist?(CONFIG_PATH)
      Rails.logger.error("[DataFileSyncJob] Missing config file: #{CONFIG_PATH}")
      return []
    end

    body = JSON.parse(File.read(CONFIG_PATH.to_s))
    Array(body['servers']).filter_map { |server| normalize_server_config(server) }
  rescue JSON::ParserError => e
    Rails.logger.error("[DataFileSyncJob] Invalid JSON config: #{e.message}")
    []
  end

  def normalize_server_config(raw_server)
    server = raw_server.is_a?(Hash) ? raw_server : {}

    nickname = safe_name(server['nickname'])
    host = resolve_value(server['host'])
    username = resolve_value(server['username'])
    password = resolve_value(server['password'])

    if nickname.blank? || host.blank? || username.blank? || password.blank?
      Rails.logger.error('[DataFileSyncJob] Invalid server config entry (nickname/host/username/password required); skipping')
      return nil
    end

    {
      nickname: nickname,
      host: host,
      username: username,
      password: password,
      passive: ActiveModel::Type::Boolean.new.cast(server.fetch('passive', true)),
      dirs: Array(server['dirs']).filter_map { |dir| normalize_dir_config(dir) }
    }
  end

  def normalize_dir_config(raw_dir)
    return raw_dir.to_s if raw_dir.is_a?(String) && raw_dir.present?

    remote = raw_dir.is_a?(Hash) ? raw_dir['remote'].to_s : ''
    remote.presence
  end

  def sync_server(server_config)
    if server_config[:dirs].blank?
      Rails.logger.info("[DataFileSyncJob] No dirs configured for #{server_config[:nickname]}; skipping server")
      return
    end

    Net::FTP.open(server_config[:host], server_config[:username], server_config[:password]) do |ftp|
      ftp.passive = server_config[:passive]

      server_config[:dirs].each do |remote_dir|
        sync_remote_dir(ftp, server_config, remote_dir)
      end
    end
  rescue StandardError => e
    Rails.logger.error("[DataFileSyncJob] Failed to sync server #{server_config[:nickname]}: #{e.message}")
  end

  def sync_remote_dir(ftp, server_config, remote_dir)
    with_ftp_directory(ftp, remote_dir) do
      ftp.nlst.each do |filename|
        next if ['.', '..'].include?(filename)

        download_ftp_asset(server_config[:nickname], ftp, filename)
      end
    end
  rescue StandardError => e
    Rails.logger.error("[DataFileSyncJob] Failed syncing #{server_config[:nickname]}:#{remote_dir} (#{e.message})")
  end

  def with_ftp_directory(ftp, remote_dir)
    original_dir = ftp.pwd
    ftp.chdir(remote_dir)
    yield
  ensure
    begin
      ftp.chdir(original_dir)
    rescue StandardError
      nil
    end
  end

  def resolve_value(value)
    return nil if value.nil?

    text = value.to_s
    return ENV[text.delete_prefix('env:')] if text.start_with?('env:')

    text
  end

  def download_ftp_asset(nickname, ftp, filename)
    kind = Directory.sync_kind_for_filename(filename)
    return if kind.blank?

    destination_root = Directory.sync_download_root(kind: kind, nickname: nickname)
    return if destination_root.blank?

    FileUtils.mkdir_p(destination_root)
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
    File.utime(Time.current, remote_mtime, destination_path) if remote_mtime
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
    value.to_s.gsub(/[^A-Za-z0-9._-]/, '_').downcase
  end
end
