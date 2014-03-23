class Round < ActiveRecord::Base
  scope :basic, :include => [:commander, :map, :server, :team1, :team2], :order => "start DESC"
  scope :team_stats,
    :select => "team1_id AS team_id, COUNT(*) as rounds, AVG(winner) AS wlr, teams.name",
    :joins => "LEFT JOIN teams ON teams.id = team1_id",
    :group => "team_id",
    :order => "rounds DESC",
    :having => "rounds > 10 AND team_id IS NOT NULL",
    :limit => 100

  has_many :rounders, :dependent => :destroy
  has_many :logs, :dependent => :destroy

  belongs_to :team1, :class_name => "Team"
  belongs_to :team2, :class_name => "Team"
  belongs_to :server
  belongs_to :match
  belongs_to :commander, :class_name => "Rounder"
  belongs_to :map

  def length
    sprintf("%02d:%02d", (self.end - self.start).to_i/60, (self.end - self.start).to_i%60)
  end

  def winner_s
    winner == 1 ? "Marines" : "Aliens"
  end

  def marine_stats
    {"built_resourcetower" => "Marine RTs",
     "built_item_genericammo" => "Ammo Packs",
     "built_item_health" => "Medpacks"}
  end

  def alien_stats
    {"built_alienresourcetower" => "Alien RTs",
     "lerk" => "Lerks",
     "fade" => "Fades",
     "onos" => "Onoses"}
  end

  def self.marine_events
    {"built_resourcetower" => "RT Built",
     "built_phasegate" => "PG Built",
     "built_team_infportal" => "IP Built",
     "built_team_armory" => "Armory Built",
     "built_team_observatory" => "Obs Built",
     "built_team_armslab" => "ARMS Built",
     "built_team_command" => "CC Built",
     "built_team_prototypelab" => "Proto Built",
     "built_team_turretfactory" => "TF Built",
     "built_team_turret" => "Turret Built",
     "built_team_siegeturret" => "Siege Built",
     "destroyed_resourcetower" => "RT Destroyed",
     "destroyed_phasegate" => "PG Destroyed",
     "destroyed_team_infportal" => "IP Destroyed",
     "destroyed_team_armory" => "Armory Destroyed",
     "destroyed_team_observatory" => "Obs Destroyed",
     "destroyed_team_armslab" => "ARMS Destroyed",
     "destroyed_team_command" => "CC Destroyed",
     "destroyed_team_prototypelab" => "Proto Destroyed",
     "destroyed_team_turretfactory" => "TF Destroyed",
     "destroyed_team_turret" => "Turret Destroyed",
     "destroyed_team_siegeturret" => "Siege Destroyed",
     "scan" => "Scan",
     "research_motiontracking" => "MT Tech",
     "research_phasetech" => "PG Tech",
     "research_distressbeacon" => "Beacon",
     "research_armorl1" => "Armor 1",
     "research_armorl2" => "Armor 2",
     "research_armorl3" => "Armor 3",
     "research_weaponsl1" => "Weapons 1",
     "research_weaponsl2" => "Weapons 2",
     "research_weaponsl3" => "Weapons 3",
     "research_advarmory" => "AA",
     "research_electrical" => "Electrify",
     "research_advturretfactory" => "A-TFAC",
     "research_cancel" => "Research Cancel",
     "kill" => "Frag"}
  end

  def self.alien_events
    {"built_team_hive" => "Hive Built",
     "built_movementchamber" => "MC Built",
     "built_sensorychamber" => "SC Built",
     "built_defensechamber" => "DC Built",
     "built_offensechamber" => "OC Built",
     "built_alienresourcetower" => "RT Built",
     "destroyed_team_hive" => "Hive Destroyed",
     "destroyed_movementchamber" => "MC Destroyed",
     "destroyed_sensorychamber" => "SC Destroyed",
     "destroyed_defensechamber" => "DC Destroyed",
     "destroyed_offensechamber" => "OC Destroyed",
     "destroyed_alienresourcetower" => "RT Destroyed",
     "gorge" => "Gorge up",
     "lerk" => "Lerk up",
     "fade" => "Fade up",
     "onos" => "Onos up",
     "kill" => "Frag"}
  end

  def self.alien_event event
    return alien_events[event] if alien_events.include?(event)
    return nil
  end

  def self.marine_event event
    return marine_events[event] if marine_events.include?(event)
    return nil
  end
end
