class Log < ActiveRecord::Base
  include Extra
  attr_accessor :text

  DOMAIN_LOG = 1
  DOMAIN_RCON_COMMAND = 2
  DOMAIN_RCON_RESPONSE = 3
  DOMAIN_INFO = 4

  TEAM_MARINES = 1
  TEAM_ALIENS = 2

  RE_PLAYER = /".*?<\d*><STEAM_\d*:\d*:\d*><\w*>"/
    RE_PLAYER_ID = /".*?<\d*><STEAM_(\d*:\d*:\d*)><\w*>"/
    RE_PLAYER_ID_NAME_TEAM = /"(.*?)<\d*><STEAM_(\d*:\d*:\d*)><([a-z]*)1team>"/
    RE_PLAYER_NAME = /"(.*?)<\d*><STEAM_\d*:\d*:\d*><[a-z]*1team>"/
    RE_PLAYER_NAME_TEAM = /"(.*?)<\d*><STEAM_\d*:\d*:\d*><([a-z]*)1team>"/

    scope :recent, :order => "id DESC", :limit => 5
  scope :ordered, :order => "created_at ASC, id ASC"
  scope :with_details,
    lambda { |details| {:conditions => ["details LIKE ?", details]} }
  scope :unhandled, :conditions => {:details => nil}
  scope :stats,
    :select => "id, details, COUNT(*) as num",
    :group => "details",
    :order => "details"

  belongs_to :details, :class_name => "LogEvent"
  belongs_to :server
  belongs_to :round
  belongs_to :server
  belongs_to :log_file
  belongs_to :actor, :class_name => "Rounder"
  belongs_to :target, :class_name => "Rounder"

  #	def domains
  #		return {DOMAIN_LOG => "HL Log", DOMAIN_RCON_COMMAND => "Rcon Command Log", DOMAIN_RCON_RESPONSE => "Rcon Response Log", DOMAIN_INFO => "Action Log"}
  #	end

  def since
    (created_at - round.start).to_i
  end

  def time
    return sprintf("%02d:%02d", since/60, since%60)
  end

  def frag
    text.match(/^#{RE_PLAYER_NAME_TEAM} killed #{RE_PLAYER_NAME_TEAM} with "([a-z0-9_]*)"$/)
  end

  def role
    text.match(/^#{RE_PLAYER_NAME} changed role to "([a-z0-9_]*)"$/)
  end

  def match_map vars
    if m = text.match(/^Started map "([A-Za-z0-9_]*)"/)
      vars[:map] = m[1]
      self.details = LogEvent.get "map"
      self.specifics1 = m[1]
    end
  end

  def match_start vars
    if text.match(/^Game reset complete.$/)
      vars[:round] = Round.new
      vars[:round].server = server
      vars[:round].start = created_at
      vars[:round].map_name = vars[:map]
      vars[:round].map = Map.with_name(vars[:map]).first
      vars[:round].save
      vars[:lifeforms] = {}
      self.details = LogEvent.get "start"
    end
  end

  def match_end vars
    if m = text.match(/^Team ([1-2]) has lost.$/)
      vars[:round].winner = (m[1].to_i == 1 ? 2 : 1)
      vars[:round].end = created_at
      [1, 2].each do |team|
        if s = vars[:round].rounders.team(team).stats.first
          vars[:round]["team#{team}_id"] = s["team_id"]
        end
      end
      vars[:round].save
      vars[:round] = nil
      self.details = LogEvent.get "end"
  end
        end

        def match_join vars
          if m = text.match(/^#{RE_PLAYER_ID_NAME_TEAM} .*$/) and !(self.actor = vars[:round].rounders.match(m[2]).first)
            self.actor = Rounder.new
            self.actor.round = vars[:round]
            self.actor.name = m[1]
            self.actor.steamid = m[2]
            self.actor.user = User.first(:conditions => {:steamid => m[2]}) or User.historic(m[2])
            self.actor.team = (m[3] == "marine" ? TEAM_MARINES : TEAM_ALIENS)
            if self.actor.user and t = Teamer.historic(actor.user, vars[:round].start).first
              self.actor.ensl_team = t.team
            end
            self.actor.kills = 0
            self.actor.deaths = 0
            self.actor.save
            self.details = LogEvent.get "join"
          end
        end

        def match_kill vars
          if m = text.match(/^#{RE_PLAYER} killed #{RE_PLAYER_ID} with "([a-z0-9_]*)"$/)
            if self.actor
              actor.increment :kills
              actor.save
            end
            if self.target = vars[:round].rounders.match(m[1]).first
              target.increment :deaths
              target.save
            end
            self.details = LogEvent.get "kill"
            self.specifics1 = m[3]
            save
          end
        end

        def match_say vars
          if m = text.match(/^#{RE_PLAYER} (say(_team)?) ".*"$/)
            self.details = "say"
            self.specifics1 = m[1]
          end
        end

        def match_built vars
          if m = text.match(/^#{RE_PLAYER} triggered "structure_built" \(type "([a-z0-9_]*)"\)$/)
            self.details = "built_" + m[1]
          end
        end

        def match_destroyed vars
          if m = text.match(/^#{RE_PLAYER} triggered "structure_destroyed" \(type "([a-z0-9_]*)"\)$/)
            self.details = "destroyed_" + m[1]
          end
        end

        def match_research_start vars
          if m = text.match(/^#{RE_PLAYER} triggered "research_start" \(type "([a-z0-9_]*)"\)$/)
            self.details = m[1]
          end
        end

        def match_research_cancel vars
          if m = text.match(/^#{RE_PLAYER} triggered "research_cancel" \(type "([a-z0-9_]*)"\)$/)
            self.details = "research_cancel"
          end
        end

        def match_role vars
          if m = text.match(/^#{RE_PLAYER_ID} changed role to "([a-z0-9_]*)"$/)
            if m[2] == "gestate"
              self.details = "gestate"
            elsif actor
              if m[2] == "commander" and !vars[:round].commander
                vars[:round].commander = actor
                vars[:round].save
              end
              if !actor.roles
                actor.update_attribute :roles, m[2]
              elsif !self.actor.roles.include?(m[2])
                actor.update_attribute :roles, actor.roles + ", " + m[2]
              end
              self.details = ((vars[:lifeforms].include? actor.id and vars[:lifeforms][actor.id] == m[2]) ? "upgrade" : m[2])
              vars[:lifeforms][actor.id] = m[2]
            end
          end
        end

        def self.add server, domain, text
          log = new
          log.server = server
          log.domain = domain
          log.text = text
          log.save
        end
end
