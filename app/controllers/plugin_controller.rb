class PluginController < ApplicationController
  # FIXME: think this again. Use API.
  # Most logic should be in here no in AMXX
  # Use JSON?

  def user
    buffer = []
    out = []
    
    if ban = Ban.server_ban(params[:id]).count > 0
      out << "#USER#"
      out << "BANNED"
      out << ban.expiry.utc.to_i
      out << ban.reason
      out << "\r\r\r\r\r\r\r"
    elsif user = User.where(steamid: params[:id]).first
      icon = 0
      rank = "User"
      if user.groups.exists? id: Group::DONORS
        rank = "Donor"
        icon = icon | 1
      end
      if user.groups.exists? id: Group::CHAMPIONS
        icon = icon | 2
      end
      if user.ref?
        rank = "Referee"
        icon = icon | 4
      end
      if user.admin?
        rank = "Admin"
        icon = icon | 8
      end

      buffer << user.steamid
      buffer << user.username
      buffer << '0.0.0.0'
      buffer << (user.team ? Verification.uncrap(user.team.to_s) : "No Team")
      buffer << user.id
      buffer << user.team_id
      buffer << rank
      buffer << user&.current_teamer.rank_s
      buffer << icon
      buffer << params[:ch] ? params[:ch] : ""
      buffer << (user.can_play? ? "1" : "0")

      out << "#USER#"
      out << Verification.verify(buffer.join)
      out << buffer.join("\r")
    else
      out << "#FAIL#"
    end

    render_out out
  end

  def render_out out
    @text = out.join("\r")
    render :layout => false
  end
end