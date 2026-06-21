# frozen_string_literal: true

module ServersHelper
  def server_status_label(server)
    return 'Status: online' if server.online?

    since = server_offline_since(server)
    return 'Status: offline' unless since

    "Status: offline since #{distance_of_time_in_words(since, Time.current)}"
  end

  private

  def server_offline_since(server)
    return nil unless server.status == Server::STATUS_OFFLINE

    server.versions
          .where('object LIKE ?', "%status: #{Server::STATUS_ONLINE}%")
          .order(created_at: :desc)
          .limit(1)
          .pick(:created_at)
  rescue StandardError
    nil
  end
end
