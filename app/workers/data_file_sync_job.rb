# frozen_string_literal: true

require 'fileutils'
require 'json'
require 'net/ftp'
require 'securerandom'

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
    Array(body['servers']).filter_map do |raw_server|
      server = raw_server.is_a?(Hash) ? raw_server : {}
      nickname = Directory.sanitize_sync_segment(server['nickname'])
      host = resolve_value(server['host'])
      username = resolve_value(server['username'])
      password = resolve_value(server['password'])

      if nickname.blank? || host.blank? || username.blank? || password.blank?
        Rails.logger.error('[DataFileSyncJob] Invalid server config entry (nickname/host/username/password required); skipping')
        next
      end

      dirs = Array(server['dirs']).filter_map do |raw_dir|
        if raw_dir.is_a?(String)
          raw_dir.presence
        elsif raw_dir.is_a?(Hash)
          raw_dir['remote'].to_s.presence
        end
      end

      {
        nickname: nickname,
        host: host,
        username: username,
        password: password,
        passive: ActiveModel::Type::Boolean.new.cast(server.fetch('passive', true)),
        dirs: dirs
      }
    end
  rescue JSON::ParserError => e
    Rails.logger.error("[DataFileSyncJob] Invalid JSON config: #{e.message}")
    []
  end

  def sync_server(server_config)
    if server_config[:dirs].blank?
      Rails.logger.info("[DataFileSyncJob] No dirs configured for #{server_config[:nickname]}; skipping server")
      return
    end

    Net::FTP.open(server_config[:host], server_config[:username], server_config[:password]) do |ftp|
      ftp.passive = server_config[:passive]

      server_config[:dirs].each do |remote_dir|
        original_dir = ftp.pwd
        ftp.chdir(remote_dir)

        ftp.nlst.each do |filename|
          next if ['.', '..'].include?(filename)

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

          plan = DataFile.sync_download_plan(
            nickname: server_config[:nickname],
            filename: filename,
            remote_size: remote_size,
            remote_mtime: remote_mtime
          )
          next if plan.blank?

          unless plan[:download]
            Rails.logger.info("[DataFileSyncJob] Skipping up-to-date file #{plan[:destination_path]}")
            next
          end

          download_path = plan[:destination_path]
          FileUtils.mkdir_p(File.dirname(download_path))
          temp_path = "#{download_path}.part-#{Process.pid}-#{SecureRandom.hex(4)}"
          ftp.getbinaryfile(filename, temp_path)
          FileUtils.mv(temp_path, download_path, force: true)
          File.utime(Time.current, remote_mtime, download_path) if remote_mtime
          Rails.logger.info("[DataFileSyncJob] Downloaded FTP asset #{filename} -> #{download_path}")
        ensure
          FileUtils.rm_f(temp_path) if defined?(temp_path)
        end
      rescue StandardError => e
        Rails.logger.error("[DataFileSyncJob] Failed syncing #{server_config[:nickname]}:#{remote_dir} (#{e.message})")
      ensure
        begin
          ftp.chdir(original_dir)
        rescue StandardError
          nil
        end
      end
    end
  rescue StandardError => e
    Rails.logger.error("[DataFileSyncJob] Failed to sync server #{server_config[:nickname]}: #{e.message}")
  end

  def resolve_value(value)
    return nil if value.nil?

    text = value.to_s
    return ENV[text.delete_prefix('env:')] if text.start_with?('env:')

    text
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
end
