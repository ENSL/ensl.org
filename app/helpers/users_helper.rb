# frozen_string_literal: true

module UsersHelper
  def steamid_tool
    df = DataFile.where("name LIKE '%SteamID Finder%'").first
    df ? data_file_url(df) : '/'
  end
end
