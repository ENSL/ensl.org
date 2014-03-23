class PluginController < ApplicationController
  def esi
    buffer = []
    out = []
    buffer << Time.now.utc.to_i
    buffer << "1.2"
    buffer << params[:ch] ? params[:ch] : ""
    out << "#ESI#"
    out << Verification.verify(buffer.join)
    out << buffer.join("\r")
    render_out out
  end

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

  #def admin
  #	areq = AdminRequest.new
  #	areq.addr = params[:addr]
  #	areq.pwd = params[:pwd]
  #	areq.msg = params[:msg]
  #	areq.player = params[:player]
  #	areq.user_id = params[:user]
  #	areq.save!
  #	render :text => "Ok"
  #end

  def ban
    ban = Ban.new
    ban.steamid = params[:id]
    ban.ts = params[:ts]
    ban.sign = params[:sign]
    ban.expiry = DateTime.now.ago(-(params[:len].to_i*60))
    ban.addr = params[:addr]
    ban.reason = params[:reason]
    ban.ban_type = Ban::TYPE_SERVER
    ban.save!

    render :text => "Ok"
  end

  def hltv_req
    if params[:game].to_i > 0
      if match = Match.first(:conditions => {:id => params[:game]})
        match.hltv_record params[:addr], params[:pwd]
        hltv = match.hltv
      else
        render :text => t(:matches_notfound)
      end
    else
      hltv = Server.hltvs.active.unreserved_now.unreserved_hltv_around(DateTime.now).first unless hltv
      render :text => t(:hltv_notavailable) unless hltv

      hltv.recording = params[:game]
      hltv.reservation = params[:addr]
      hltv.pwd = params[:pwd]
      hltv.save!
    end

    render :text => t(:hltv_sent)
  end

  def hltv_move
    Server.move params[:addr], params[:newaddr], params[:newpwd]
    render :text => t(:hltv_movedd) + params[:newaddr]
  end

  def hltv_stop
    Server.stop params[:addr]
    render :text => t(:hltv_stopped)
  end

  private

  def render_out out
    @text = out.join("\r")
    render :layout => false
  end
end
