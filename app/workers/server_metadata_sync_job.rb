# frozen_string_literal: true

class ServerMetadataSyncJob
  include Sidekiq::Job

  sidekiq_options queue: :default, retry: 3

  def perform(_options = {})
    scope = Server.active.where(domain: [Server::DOMAIN_HLDS, Server::DOMAIN_NS2])
    total = scope.count
    hlds_total = scope.where(domain: Server::DOMAIN_HLDS).count
    ns2_total = scope.where(domain: Server::DOMAIN_NS2).count
    responded = 0
    updated = 0
    offline = 0

    scope.find_each do |server|
      outcome = sync_server(server)
      case outcome
      when :updated
        responded += 1
        updated += 1
      when :responded
        responded += 1
      when :offline
        offline += 1
      end
    end

    Rails.logger.info(
      "[ServerMetadataSyncJob] total=#{total} hlds=#{hlds_total} ns2=#{ns2_total} responded=#{responded} updated=#{updated} offline=#{offline}"
    )
  end

  private

  def sync_server(server)
    snapshot = fetch_server_snapshot(server)
    info = snapshot[:info]

    updates = {}

    ping_value = snapshot[:ping]
    updates[:ping] = ping_value.round.to_s if ping_value

    updates[:status] = Server::STATUS_ONLINE if server.status != Server::STATUS_ONLINE

    map_name = info[:map_name].presence
    updates[:map] = map_name if map_name && map_name != server.map

    max_players = info[:max_players]
    if max_players.present?
      normalized_max_players = max_players.to_i
      updates[:max_players] = normalized_max_players if normalized_max_players != server.max_players
    end

    if updates.empty?
      Rails.logger.debug("[ServerMetadataSyncJob] #{server.id} #{server.addr} responded without changes")
      return :responded
    end

    changed_fields = updates.keys
    server.update!(updates)
    Rails.logger.debug(
      "[ServerMetadataSyncJob] #{server.id} #{server.addr} updated: #{changed_fields.join(', ')}"
    )
    :updated
  rescue StandardError => e
    mark_offline(server, e)
    :offline
  end

  def fetch_server_snapshot(server)
    errors = []

    query_classes_for(server).each do |server_class|
      query_server = server_class.new(server.ip, server.port.to_i)
      query_server.update_ping

      info = query_server.server_info
      info = {} unless info.is_a?(Hash)

      return { ping: query_server.ping, info: info }
    rescue StandardError => e
      errors << "#{server_class.name}: #{e.class}: #{e.message}"
    end

    raise StandardError, errors.join(' | ')
  end

  def query_classes_for(server)
    case server.domain
    when Server::DOMAIN_HLDS
      [SteamCondenser::Servers::GoldSrcServer, SteamCondenser::Servers::SourceServer]
    when Server::DOMAIN_NS2
      [SteamCondenser::Servers::SourceServer]
    else
      [SteamCondenser::Servers::SourceServer]
    end
  end

  def mark_offline(server, error)
    updates = {}
    updates[:status] = Server::STATUS_OFFLINE if server.status != Server::STATUS_OFFLINE
    updates[:ping] = nil if server.ping.present?

    server.update!(updates) if updates.any?

    Rails.logger.debug("[ServerMetadataSyncJob] #{server.id} #{server.addr} offline: #{error.class}: #{error.message}")
  rescue StandardError => e
    Rails.logger.error("[ServerMetadataSyncJob] Failed to mark server #{server.id} offline: #{e.class}: #{e.message}")
  end
end
