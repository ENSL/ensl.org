class Rounder < ActiveRecord::Base
  attr_accessor :lifeform

  scope :team, lambda { |team| {:conditions => {:team => team}} }
  scope :match, lambda { |steamid| {:conditions => {:steamid => steamid}} }
  scope :ordered, :order => "kills DESC, deaths ASC"
  scope :stats,
    :select => "id, team_id, COUNT(*) as num",
    :group => "team_id",
    :order => "num DESC",
    :having => "num > 3"
  scope :player_stats,
    :select => "id, user_id, SUM(kills)/SUM(deaths) as kpd, COUNT(*) as rounds",
    :group => "user_id",
    :order => "kpd DESC",
    :having => "rounds > 30 AND kpd > 0 AND user_id IS NOT NULL",
    :limit => 100
  scope :team_stats,
    :select => "id, team_id, SUM(kills)/SUM(deaths) as kpd, COUNT(DISTINCT round_id) as rounds",
    :group => "team_id",
    :order => "kpd DESC",
    :having => "rounds > 30 AND kpd > 0 AND team_id IS NOT NULL",
    :limit => 100
  scope :extras, :include => [:round, :user]
  scope :within,
    lambda { |from, to|
    {:conditions => ["created_at > ? AND created_at < ?", from.utc, to.utc]} }

    belongs_to :round
    belongs_to :user
    belongs_to :ensl_team, :class_name => "Team", :foreign_key => "team_id"

    def to_s
      user ? user.username : name
    end
end
