# frozen_string_literal: true

require 'cgi'
require 'fileutils'
require 'json'
require 'net/http'
require 'uri'

class GithubReleaseAssetSyncJob
  include Sidekiq::Job

  sidekiq_options queue: :default, retry: 5

  DEFAULT_REPO = 'ENSL/NS'
  GITHUB_API_BASE = 'https://api.github.com'
  USER_AGENT = 'ensl-sidekiq-github-release-sync'

  def perform(options = {})
    opts = options.is_a?(Hash) ? options : {}
    repo = opts['repo'].presence || opts[:repo].presence || DEFAULT_REPO
    destination_root = File.join(ENV['FILES_ROOT'], 'client')
    FileUtils.mkdir_p(destination_root)

    fetch_tags(repo).each do |tag|
      fetch_release_assets(repo).fetch(tag, []).uniq.each do |asset_url|
        download_asset(destination_root, asset_url, prefix: tag)
      end
    end

    root_directory = Directory.find_by(id: Directory::ROOT)
    DirectoryReconciliationService.new(root_directory).call if root_directory
  end

  private

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
    next_part && next_part[/<([^>]+)>/, 1]
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

    if filename.present? && DataFile.exists?(name: filename)
      Rails.logger.info("[GithubReleaseAssetSyncJob] Skipping existing DB file #{filename}")
      return
    end

    if File.exist?(destination_path)
      Rails.logger.info("[GithubReleaseAssetSyncJob] Skipping existing file #{destination_path}")
      return
    end

    uri = URI.parse(asset_url)
    response = Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == 'https') do |http|
      request = Net::HTTP::Get.new(uri)
      request['User-Agent'] = USER_AGENT
      http.open_timeout = 20
      http.read_timeout = 120
      http.request(request)
    end

    raise "Download failed with #{response.code}" unless response.is_a?(Net::HTTPSuccess)

    File.open(destination_path, 'wb') { |file| file.write(response.body) }

    Rails.logger.info("[GithubReleaseAssetSyncJob] Downloaded #{asset_url} -> #{destination_path}")
  rescue StandardError => e
    Rails.logger.error("[GithubReleaseAssetSyncJob] Failed to download #{asset_url}: #{e.message}")
  end

  def filename_for(asset_url, prefix)
    basename = File.basename(URI.parse(asset_url).path.to_s)
    basename = CGI.unescape(basename)
    basename = 'asset' if basename.blank?
    prefix.blank? ? basename : "#{safe_name(prefix)}__#{basename}"
  rescue URI::InvalidURIError
    prefix.blank? ? 'asset' : "#{safe_name(prefix)}__asset"
  end

  def safe_name(value)
    value.to_s.gsub(/[^A-Za-z0-9._-]/, '_').downcase
  end
end
