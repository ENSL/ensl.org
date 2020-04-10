module SteamID
  def self.to_steamID(steamid)
    m = steamid.match(/^(STEAM_){0,1}([0-5]):([01]:\d+)$/)
    return ((m[3].to_i * 2) + m[2].to_i) + 76561197960265728
  end

  def self.from_steamID64(sid)
    y = sid.to_i - 76561197960265728
    x = y % 2
    return "0:%d:%d" % [x, (y - x).div(2)]
  end
end