# frozen_string_literal: true

# == Schema Information
#
# Table name: log_lines
#
#  id          :integer          not null, primary key
#  server_id   :integer
#  text        :text
#  domain      :integer
#  created_at  :datetime
#  round_id    :integer
#  details     :string(255)
#  actor_id    :integer
#  target_id   :integer
#  specifics1  :string(255)
#  specifics2  :string(255)
#  log_file_id :integer
#

class LogLine < ApplicationRecord
  include Extra
  attr_accessor :text

  DOMAIN_LOG = 1
  DOMAIN_INFO = 4

  TEAM_MARINES = 1
  TEAM_ALIENS = 2

  RE_PLAYER = /".*?<\d*><STEAM_\d*:\d*:\d*><\w*>"/
  RE_PLAYER_ID = /".*?<\d*><STEAM_(\d*:\d*:\d*)><\w*>"/
  RE_PLAYER_ID_NAME_TEAM = /"(.*?)<\d*><STEAM_(\d*:\d*:\d*)><([a-z]*)1team>"/
  RE_PLAYER_NAME = /"(.*?)<\d*><STEAM_\d*:\d*:\d*><[a-z]*1team>"/
  RE_PLAYER_NAME_TEAM = /"(.*?)<\d*><STEAM_\d*:\d*:\d*><([a-z]*)1team>"/

  scope :recent, -> { order(id: :desc).limit(5) }
  scope :ordered, -> { order(:created_at, :id) }
  scope :stats,
        lambda {
          select('id, details, COUNT(*) as num')
            .group('details')
            .order('details')
        }

  belongs_to :details, class_name: 'LogEvent'
  belongs_to :server
  belongs_to :round
  belongs_to :server, optional: true
  belongs_to :log_file
  belongs_to :actor, class_name: 'Rounder'
  belongs_to :target, class_name: 'Rounder'

  def since
    (created_at - round.start).to_i
  end

  def time
    format('%<minutes>02d:%<seconds>02d', minutes: since / 60, seconds: since % 60)
  end

  def frag
    text.match(/^#{RE_PLAYER_NAME_TEAM} killed #{RE_PLAYER_NAME_TEAM} with "([a-z0-9_]*)"$/)
  end

  def role
    text.match(/^#{RE_PLAYER_NAME} changed role to "([a-z0-9_]*)"$/)
  end

  def match_map(vars)
    return unless (m = text.match(/^Started map "([A-Za-z0-9_]*)"/))

    vars[:map] = m[1]
    self.details = LogEvent.get 'map'
    self.specifics1 = m[1]
  end

  def match_start(vars)
    return unless text.match(/^Game reset complete.$/)

    vars[:round] = Round.new
    vars[:round].server = server
    vars[:round].start = created_at
    vars[:round].map_name = vars[:map]
    vars[:round].map = Map.with_name(vars[:map]).first
    vars[:round].save
    vars[:lifeforms] = {}
    self.details = LogEvent.get 'start'
  end

  def match_end(vars)
    return unless (m = text.match(/^Team ([1-2]) has lost.$/))

    vars[:round].winner = (m[1].to_i == 1 ? 2 : 1)
    vars[:round].end = created_at
    [1, 2].each do |team|
      if (s = vars[:round].rounders.team(team).stats.first)
        vars[:round]["team#{team}_id"] = s['team_id']
      end
    end
    vars[:round].save
    vars[:round] = nil
    self.details = LogEvent.get 'end'
  end

  def match_join(vars)
    if (m = text.match(/^#{RE_PLAYER_ID_NAME_TEAM} .*$/)) && !(self.actor = vars[:round].rounders.match(m[2]).first)
      self.actor = Rounder.new
      actor.round = vars[:round]
      actor.name = m[1]
      actor.steamid = m[2]
      actor.user = User.find_by(steamid: m[2]) or User.historic(m[2])
      actor.team = (m[3] == 'marine' ? TEAM_MARINES : TEAM_ALIENS)
      if actor.user && (t = Teamer.historic(actor.user, vars[:round].start).first)
        actor.ensl_team = t.team
      end
      actor.kills = 0
      actor.deaths = 0
      actor.save
      self.details = LogEvent.get 'join'
    end
  end

  def match_kill(vars)
    return unless (m = text.match(/^#{RE_PLAYER} killed #{RE_PLAYER_ID} with "([a-z0-9_]*)"$/))

    if actor
      actor.increment :kills
      actor.save
    end
    if (self.target = vars[:round].rounders.match(m[1]).first)
      target.increment :deaths
      target.save
    end
    self.details = LogEvent.get 'kill'
    self.specifics1 = m[3]
    save
  end

  def match_say(_vars)
    return unless (m = text.match(/^#{RE_PLAYER} (say(_team)?) ".*"$/))

    self.details = 'say'
    self.specifics1 = m[1]
  end

  def match_built(_vars)
    return unless (m = text.match(/^#{RE_PLAYER} triggered "structure_built" \(type "([a-z0-9_]*)"\)$/))

    self.details = "built_#{m[1]}"
  end

  def match_destroyed(_vars)
    return unless (m = text.match(/^#{RE_PLAYER} triggered "structure_destroyed" \(type "([a-z0-9_]*)"\)$/))

    self.details = "destroyed_#{m[1]}"
  end

  def match_research_start(_vars)
    return unless (m = text.match(/^#{RE_PLAYER} triggered "research_start" \(type "([a-z0-9_]*)"\)$/))

    self.details = m[1]
  end

  def match_research_cancel(_vars)
    return unless text.match(/^#{RE_PLAYER} triggered "research_cancel" \(type "([a-z0-9_]*)"\)$/)

    self.details = 'research_cancel'
  end

  def match_role(vars)
    return unless (m = text.match(/^#{RE_PLAYER_ID} changed role to "([a-z0-9_]*)"$/))

    if m[2] == 'gestate'
      self.details = 'gestate'
    elsif actor
      if (m[2] == 'commander') && !vars[:round].commander
        vars[:round].commander = actor
        vars[:round].save
      end
      if !actor.roles
        actor.update_attribute :roles, m[2]
      elsif !actor.roles.include?(m[2])
        actor.update_attribute :roles, "#{actor.roles}, #{m[2]}"
      end
      self.details = (vars[:lifeforms].include?(actor.id) && (vars[:lifeforms][actor.id] == m[2]) ? 'upgrade' : m[2])
      vars[:lifeforms][actor.id] = m[2]
    end
  end

  def self.add(server, domain, text)
    log = new
    log.server = server
    log.domain = domain
    log.text = text
    log.save
  end
end
