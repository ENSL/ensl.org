# == Schema Information
#
# Table name: gathers
#
#  id          :integer          not null, primary key
#  status      :integer
#  captain1_id :integer
#  captain2_id :integer
#  map1_id     :integer
#  map2_id     :integer
#  server_id   :integer
#  created_at  :datetime
#  updated_at  :datetime
#  turn        :integer
#  lastpick1   :datetime
#  lastpick2   :datetime
#  votes       :integer          default(0), not null
#  category_id :integer
#

class Gather < ActiveRecord::Base
  STATE_RUNNING = 0
  STATE_VOTING = 3
  STATE_PICKING = 1
  STATE_FINISHED = 2
  NOTIFY = 6
  FULL = 12
  SERVERS = [3, 5, 23, 21, 22]

  attr_accessor :admin

  scope :ordered, -> { order("id DESC") }
  scope :basic, -> { include(:captain1, :captain2, :map1, :map2, :server) }
  scope :active, -> { where("gathers.status IN (?, ?, ?) AND gathers.updated_at > ?",
                            STATE_VOTING, STATE_PICKING, STATE_RUNNING, 12.hours.ago.utc) }
  
  belongs_to :server
  belongs_to :captain1, :class_name => "Gatherer"
  belongs_to :captain2, :class_name => "Gatherer"
  belongs_to :map1, :class_name => "GatherMap"
  belongs_to :map2, :class_name => "GatherMap"
  belongs_to :category

  has_many :gatherers
  has_many :users, :through => :gatherers
  has_many :gatherer_votes, :through => :gatherers, :source => :real_votes
  has_many :map_votes, :through => :gather_maps, :source => :real_votes
  has_many :gather_maps, :class_name => "GatherMap"
  has_many :maps, :through => :gather_maps
  has_many :server_votes, :through => :gather_servers, :source => :real_votes
  has_many :gather_servers, :class_name => "GatherServer"
  has_many :servers, :through => :gather_servers
  has_many :shoutmsgs, :as => "shoutable"
  has_many :real_votes, :class_name => "Vote", :as => :votable, :dependent => :destroy

  before_create :init_variables
  after_create :add_maps_and_server
  before_save :check_status
  before_save :check_captains

  def to_s
    "Gather_#{self.id}"
  end

  def self.find_game(name)
    Category.where(name: name, domain: Category::DOMAIN_GAMES).first
  end

  def self.player_count_for_game(name)
    game = self.find_game(name)

    if game && (players = game.gathers.ordered.first.gatherers.count)
      players
    else
      0
    end
  end

  def demo_name
    Verification.uncrap("gather-#{self.id}")
  end

  def states
    {STATE_RUNNING => "Running", STATE_PICKING => "Picking", STATE_FINISHED => "Finished"}
  end

  def votes_needed?
    5
  end

  def first
    Gather.where(:category_id => category_id).order("id ASC").first
  end

  def previous_gather
    Gather.first.where("id < ? AND category_id = ?", self.id, category_id).order("id DESC")
  end

  def next_gather
    Gather.first.where("id > ? AND category_id = ?", self.id, category_id).order("id ASC")
  end

  def last
    Category.find(category_id).gathers.ordered.first
  end

  def init_variables
    self.status = STATE_RUNNING
  end

  def add_maps_and_server
    category.maps.basic.classic.each do |m|
      maps << m
    end

    (category_id == 44 ? category.servers.hlds.active.ordered : category.servers.active.ordered).each do |s|
      servers << s
    end
  end

  def check_status
    if status_changed? and status == STATE_PICKING and !self.captain1
      g = Gather.new
      g.category = self.category
      g.save
      self.captain1 = self.gatherers.most_voted[1]
      self.captain2 = self.gatherers.most_voted[0]
      if self.gather_maps.count > 1
        self.map1 = self.gather_maps.ordered[0]
        self.map2 = self.gather_maps.ordered[1]
      elsif self.gather_maps.count > 0
        self.map1 = self.gather_maps.ordered[0]
      end
      if self.gather_servers.count > 0
        self.server = self.gather_servers.ordered[0].server
      end
    end
  end

  def check_captains
    if captain1_id_changed? or captain2_id_changed? or admin
      self.turn = 1
      self.status = STATE_PICKING
      gatherers.each do |gatherer|
        if gatherer.id == captain1_id
          gatherer.update_attributes(:team => 1, :skip_callbacks => true)
        elsif gatherer.id == captain2_id
          gatherer.update_attributes(:team => 2, :skip_callbacks => true)
        else
          gatherer.update_attributes(:team => nil, :skip_callbacks => true)
        end
      end
    end
  end

  def refresh cuser
    if status == STATE_RUNNING
      gatherers.idle.destroy_all
    elsif status == STATE_VOTING and updated_at < 60.seconds.ago and updated_at > 5.days.ago
      if status == STATE_VOTING and updated_at < 60.seconds.ago
        self.status = STATE_PICKING
        save!
      end
    elsif status == STATE_PICKING
      if turn == 1 and gatherers.team(1).count == 2 and gatherers.team(2).count == 1
        update_attribute :turn, 2
      elsif turn == 2 and gatherers.team(2).count == 3 and gatherers.team(1).count == 2
        update_attribute :turn, 1
      elsif turn == 1 and gatherers.team(1).count == 4 and gatherers.team(2).count == 3
        update_attribute :turn, 2
      elsif turn == 2 and gatherers.team(2).count == 5 and gatherers.team(1).count == 4
        update_attribute :turn, 1
      elsif turn == 1 and gatherers.team(1).count == 6 and gatherers.team(2).count == 5
        gatherers.lobby.first.update_attributes(:team => 2, :skip_callbacks => true)
        update_attribute :turn, 2
      elsif gatherers.team(1).count == 6 and gatherers.team(2).count == 6
        update_attribute :status, STATE_FINISHED
      end
    end
  end

  def can_create? cuser
    cuser and cuser.admin?
  end

  def can_update? cuser
    cuser and cuser.admin?
  end

  def self.last(name = "NS2")
    if game = self.find_game(name)
      game.gathers.ordered.first
    end
  end
end
