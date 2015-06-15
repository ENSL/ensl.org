class PluginController < ApplicationController
	def user
	  buffer = []
	  out = []

	  if ban = Ban.first(:conditions => ["expiry > UTC_TIMESTAMP() AND steamid = ? AND ban_type = ?", params[:id], Ban::TYPE_SERVER])
	    out << "#USER#"
	    out << "BANNED"
	    out << ban.expiry.utc.to_i
	    out << ban.reason
	    out << "\r\r\r\r\r\r\r"
	  elsif user = User.first(:conditions => {:steamid => params[:id]})
	    teamer = (user.team ? user.teamers.active.of_team(user.team).first : nil)
	    icon = 0
	    rank = "User"
	    if Group.find(Group::DONORS).users.exists?(user)
	      rank = "Donor"
	      icon = icon | 1
	    end
	    if Group.find(Group::CHAMPIONS).users.exists?(user)
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
	    buffer << user.lastip
	    buffer << (user.team ? Verification.uncrap(user.team.to_s) : "No Team")
	    buffer << user.id
	    buffer << user.team_id
	    buffer << rank
	    buffer << (teamer ? teamer.ranks[teamer.rank] : "")
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