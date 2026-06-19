# frozen_string_literal: true

# == Schema Information
#
# Table name: gathers
#
#  id          :integer          not null, primary key
#  lastpick1   :datetime
#  lastpick2   :datetime
#  status      :integer
#  turn        :integer
#  votes       :integer          default(0), not null
#  created_at  :datetime
#  updated_at  :datetime
#  captain1_id :integer
#  captain2_id :integer
#  category_id :integer
#  map1_id     :integer
#  map2_id     :integer
#  server_id   :integer
#
# Indexes
#
#  index_gathers_on_captain1_id  (captain1_id)
#  index_gathers_on_captain2_id  (captain2_id)
#  index_gathers_on_map1_id      (map1_id)
#  index_gathers_on_map2_id      (map2_id)
#  index_gathers_on_server_id    (server_id)
#

class Gather < ActiveRecord::Base
  STATE_RUNNING = 0
  STATE_VOTING = 3
  STATE_PICKING = 1
  STATE_FINISHED = 2
  NOTIFY = 6
  FULL = 12
  SERVERS = [3, 5, 23, 21, 22].freeze
  VOTING_TIMEOUT_SECONDS = 60
  PICK_STRATEGY_DEFAULT = '1-2-2-2-2-1'
  PICK_STRATEGIES = [
    PICK_STRATEGY_DEFAULT,
    '1-1-1-1',
    'team_pick',
    'random',
    'gather_rank',
    'ml_rank'
  ].freeze

  attr_accessor :admin

  attr_readonly :pick_strategy

  scope :ordered, -> { order('id DESC') }
  scope :basic, -> { includes(:captain1, :captain2, :map1, :map2, :server) }
  scope :active, lambda {
    where('gathers.status IN (?, ?, ?) AND gathers.updated_at > ?',
          STATE_VOTING, STATE_PICKING, STATE_RUNNING, 12.hours.ago.utc)
  }

  belongs_to :server, optional: true
  belongs_to :captain1, class_name: 'Gatherer', optional: true
  belongs_to :captain2, class_name: 'Gatherer', optional: true
  belongs_to :map1, class_name: 'GatherMap', optional: true
  belongs_to :map2, class_name: 'GatherMap', optional: true
  belongs_to :category, optional: true

  has_many :gatherers
  has_many :users, through: :gatherers
  has_many :gather_maps, class_name: 'GatherMap'
  has_many :gatherer_votes, through: :gatherers, source: :real_votes
  has_many :map_votes, through: :gather_maps, source: :real_votes
  has_many :gather_servers, class_name: 'GatherServer'
  has_many :maps, through: :gather_maps
  has_many :server_votes, through: :gather_servers, source: :real_votes
  has_many :servers, through: :gather_servers
  has_many :shoutmsgs, as: 'shoutable'
  has_many :real_votes, class_name: 'Vote', as: :votable, dependent: :destroy

  validates :pick_strategy, inclusion: { in: PICK_STRATEGIES }
  validate :pick_strategy_immutable, on: :update

  before_create :init_variables
  after_create :add_maps_and_server
  before_save :check_status
  after_save :check_captains

  def to_s
    "Gather_#{id}"
  end

  def self.find_game(name)
    Category.where(name: name, domain: Category::DOMAIN_GAMES).first
  end

  def self.player_count_for_game(name)
    game = find_game(name)

    if game && (players = game.gathers.ordered.first.gatherers.count)
      players
    else
      0
    end
  end

  def demo_name
    Verification.uncrap("gather-#{id}")
  end

  def states
    { STATE_RUNNING => 'Running', STATE_PICKING => 'Picking', STATE_FINISHED => 'Finished' }
  end

  def votes_needed?
    5
  end

  def first
    Gather.where(category_id: category_id).order('id ASC').first
  end

  def previous_gather
    Gather.where('id < ? AND category_id = ?', id, category_id).order('id DESC').first
  end

  def next_gather
    Gather.where('id > ? AND category_id = ?', id, category_id).order('id ASC').first
  end

  def last
    Category.find(category_id).gathers.ordered.first
  end

  def init_variables
    self.status = STATE_RUNNING
  end

  def bump_version!
    with_lock do
      increment!(:version)
    end
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
    changed = respond_to?(:will_save_change_to_status?) ? will_save_change_to_status? : status_changed?
    return unless changed && (status == STATE_PICKING) && !captain1

    category&.with_lock do
      Gather.create!(category: category) unless Gather.where(category_id: category_id).where('id > ?', id).exists?
    end

    self.captain1 = gatherers.most_voted[1]
    self.captain2 = gatherers.most_voted[0]
    if gather_maps.count > 1
      self.map1 = gather_maps.ordered[0]
      self.map2 = gather_maps.ordered[1]
    elsif gather_maps.count.positive?
      self.map1 = gather_maps.ordered[0]
    end
    return unless gather_servers.count.positive?

    self.server = gather_servers.ordered[0].server
  end

  def check_captains
    changed = (respond_to?(:saved_change_to_captain1_id?) ? (saved_change_to_captain1_id? || saved_change_to_captain2_id?) : (captain1_id_changed? || captain2_id_changed?))
    return unless changed

    # Ensure attributes persisted before locking and updating other records
    reload
    if admin
      # Use update_columns to avoid triggering callbacks again (preventing infinite loop)
      update_columns(turn: 1, status: STATE_PICKING, updated_at: Time.current)
    elsif changed
      self.turn = 1
      self.status = STATE_PICKING
      save!
    end

    # Lock gather to avoid concurrent updates to gatherers
    with_lock do
      captain1&.update!(team: 1, pick_order: 1, skip_callbacks: true)
      captain2&.update!(team: 2, pick_order: 2, skip_callbacks: true)

      gatherers.each do |gatherer|
        next if gatherer.id == captain1_id || gatherer.id == captain2_id

        gatherer.update!(team: nil, pick_order: nil, skip_callbacks: true)
      end
    end
  end

  def pick_strategy_immutable
    changed = respond_to?(:will_save_change_to_pick_strategy?) ? will_save_change_to_pick_strategy? : pick_strategy_changed?
    errors.add(:pick_strategy, 'cannot be changed') if changed
  end

  def refresh(_cuser)
    case status
    when STATE_RUNNING
      # DISABLED: gatherers.idle.destroy_all
    when STATE_VOTING
      # Check if voting timeout has passed based on when voting actually started
      # Use with_lock to prevent concurrent transitions from causing optimistic locking conflicts
      if voting_start_time && Time.current > voting_start_time + voting_timeout.seconds
        with_lock do
          # Re-check after acquiring lock to avoid TOCTOU race
          if status == STATE_VOTING && Time.current > voting_start_time + voting_timeout.seconds
            update!(status: STATE_PICKING)
          end
        end
      end
    when STATE_PICKING
      # Read counts outside the lock first. The version endpoint is polled by
      # every browser session concurrently; unconditionally taking with_lock
      # serialised all 12 callers even when nothing needed to change. Only
      # acquire the write lock when a transition actually appears necessary.
      t1 = gatherers.team(1).count
      t2 = gatherers.team(2).count
      cur_turn = turn

      needs_check = (t1 == 6 && t2 == 6) ||
                    (cur_turn == 1 && t1 == 2 && t2 == 1) ||
                    (cur_turn == 2 && t2 == 3 && t1 == 2) ||
                    (cur_turn == 1 && t1 == 4 && t2 == 3) ||
                    (cur_turn == 2 && t2 == 5 && t1 == 4) ||
                    (cur_turn == 1 && t1 == 6 && t2 == 5)

      if needs_check
        with_lock do
          # Re-read inside the lock (with_lock reloads the record)
          if (gatherers.team(1).count == 6) && (gatherers.team(2).count == 6)
            update!(status: STATE_FINISHED)
          elsif (turn == 1) && (gatherers.team(1).count == 2) && (gatherers.team(2).count == 1)
            update!(turn: 2)
          elsif (turn == 2) && (gatherers.team(2).count == 3) && (gatherers.team(1).count == 2)
            update!(turn: 1)
          elsif (turn == 1) && (gatherers.team(1).count == 4) && (gatherers.team(2).count == 3)
            update!(turn: 2)
          elsif (turn == 2) && (gatherers.team(2).count == 5) && (gatherers.team(1).count == 4)
            update!(turn: 1)
          elsif (turn == 1) && (gatherers.team(1).count == 6) && (gatherers.team(2).count == 5)
            gatherers.lobby.first&.update!(team: 2, skip_callbacks: true)
            update!(turn: 2)
          elsif (gatherers.team(1).count == 6) && (gatherers.team(2).count == 6)
            update!(status: STATE_FINISHED)
          end
        end
      end
    end
  end

  def can_create?(cuser)
    true if cuser.admin? || cuser.gather_moderator?
  end

  def voting_timeout
    return VOTING_TIMEOUT_SECONDS unless Rails.env.test?

    Integer(ENV.fetch('GATHER_VOTING_TIMEOUT_TEST', 10))
  end

  def voting_start_time
    # Get the time when the last (12th) gatherer joined to start voting
    return nil unless [STATE_VOTING, STATE_PICKING, STATE_FINISHED].include?(status)

    gatherers.order('created_at ASC').limit(1).offset(FULL - 1).first&.created_at
  end

  def voting_time_remaining
    return 0 unless status == STATE_VOTING
    return 0 unless (start_time = voting_start_time)

    elapsed = Time.current - start_time
    remaining = voting_timeout - elapsed.to_i
    [remaining, 0].max
  end

  def can_update?(cuser)
    true if cuser.admin? || cuser.gather_moderator?
  end

  def self.last(name = 'NS2')
    return unless (game = find_game(name))

    game.gathers.ordered.first
  end

  def self.params(params, _cuser)
    params.require(:gather).permit(:status, :captain1_id, :captain2_id, :map1_id, :map2_id, :server_id, :turn)
  end
end
