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

class Gather < ApplicationRecord
  STATE_RUNNING = 0
  STATE_VOTING = 3
  STATE_PICKING = 1
  STATE_FINISHED = 2
  NOTIFY = 6
  FULL = 12
  SERVERS = [3, 5, 23, 21, 22].freeze
  VOTING_TIMEOUT_SECONDS = 60
  RECENT_ACTIVITY_WINDOW = 1.hour
  PICK_STRATEGY_DEFAULT = Gathers::PickPlan::DEFAULT_STRATEGY
  PICK_STRATEGIES = Gathers::PickPlan::STRATEGIES.keys.freeze

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

  has_many :gatherers, dependent: :destroy
  has_many :users, through: :gatherers
  has_many :gather_maps, class_name: 'GatherMap', dependent: :destroy
  has_many :gatherer_votes, through: :gatherers, source: :real_votes
  has_many :map_votes, through: :gather_maps, source: :real_votes
  has_many :gather_servers, class_name: 'GatherServer', dependent: :destroy
  has_many :maps, through: :gather_maps
  has_many :server_votes, through: :gather_servers, source: :real_votes
  has_many :servers, through: :gather_servers
  has_many :shoutmsgs, as: 'shoutable', dependent: :destroy
  has_many :real_votes, class_name: 'Vote', as: :votable, dependent: :destroy

  validates :pick_strategy, inclusion: { in: PICK_STRATEGIES }
  validate :pick_strategy_immutable, on: :update

  before_create :initialize_state
  after_create :populate_maps_and_servers

  class << self
    def find_game(name)
      Category.where(name: name, domain: Category::DOMAIN_GAMES).first
    end

    def player_count_for_game(name)
      game = find_game(name)
      game ? game.gathers.ordered.first.gatherers.count : 0
    end

    def last(name = 'NS2')
      find_game(name)&.gathers&.ordered&.first
    end

    # Gather a user should be pointed back to: one they're currently in, or one that
    # finished recently enough that they might still be lingering around (e.g. checking
    # server info). A gather stops being "active" once an hour has passed since voting/
    # picking started (covers abandoned gathers stuck mid-pick) or once superseded by a
    # newer gather in the same category.
    def active_for_user(user)
      return nil unless user

      in_progress = user.gathers.where(status: [STATE_RUNNING, STATE_VOTING, STATE_PICKING])
                        .order(id: :desc)
                        .find { |gather| gather.status == STATE_RUNNING || gather_recently_started_picking?(gather) }
      return in_progress if in_progress

      recent = user.gathers.where(status: STATE_FINISHED)
                   .where('gathers.updated_at > ?', RECENT_ACTIVITY_WINDOW.ago)
                   .order(id: :desc).first
      return nil unless recent

      # A follow-up gather is auto-created the moment voting ends (see complete_voting!),
      # long before this one reaches FINISHED, so its mere existence doesn't mean much.
      # Only treat the old one as superseded once players have actually started joining it.
      superseded = where(category_id: recent.category_id).where('gathers.id > ?', recent.id).joins(:gatherers).exists?
      superseded ? nil : recent
    end

    def params(params, _cuser)
      params.require(:gather).permit(:status, :captain1_id, :captain2_id, :map1_id, :map2_id, :server_id, :turn)
    end

    private

    # Falls back to updated_at when voting_start_time is unavailable (e.g. a gatherer
    # left mid-pick, dropping the count below FULL) so a stuck gather can't stay
    # "active" forever just because its pick-start time can't be computed.
    def gather_recently_started_picking?(gather)
      start_time = gather.voting_start_time || gather.updated_at
      start_time.present? && start_time > RECENT_ACTIVITY_WINDOW.ago
    end
  end

  def to_s
    "Gather_#{id}"
  end

  def states
    { STATE_RUNNING => 'Running', STATE_PICKING => 'Picking', STATE_FINISHED => 'Finished' }
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

  def open_for_join?
    status == STATE_RUNNING && gatherers.count < FULL
  end

  def start_voting_if_full!
    with_lock do
      update!(status: STATE_VOTING) if gatherers.count >= FULL && status == STATE_RUNNING
    end
  end

  def notify_interested_users_if_threshold_reached!
    with_lock do
      return unless gatherers.count >= NOTIFY
    end

    Profile.where(notify_gather: 1).includes(:user).find_each do |profile|
      Notifications.gather(profile.user, self) if profile.user&.profile&.notify_pms
    end
  end

  def voting_timeout
    return VOTING_TIMEOUT_SECONDS unless Rails.env.test?

    Integer(ENV.fetch('GATHER_VOTING_TIMEOUT_TEST', 10))
  end

  def voting_start_time
    return nil unless [STATE_VOTING, STATE_PICKING, STATE_FINISHED].include?(status)

    gatherers.order('created_at ASC').limit(1).offset(FULL - 1).first&.created_at
  end

  def voting_time_remaining
    return 0 unless status == STATE_VOTING
    return 0 unless (start_time = voting_start_time)

    [voting_timeout - (Time.current - start_time).to_i, 0].max
  end

  def refresh(_cuser)
    case status
    when STATE_VOTING then refresh_voting
    when STATE_PICKING then refresh_picking
    end
  end

  def refresh_and_broadcast_if_status_changed!
    previous_status = status
    refresh(nil)
    Gathers::Broadcaster.call(self) if status != previous_status
  end

  def advance_picking_after_pick!
    with_lock do
      team1_count = gatherers.team(1).count
      team2_count = gatherers.team(2).count
      transition = pick_plan.transition(
        current_turn: turn,
        team1_count: team1_count,
        team2_count: team2_count
      )
      apply_picking_transition(transition)
    end
  end

  def picking_slot_available?
    team1_count = gatherers.team(1).count
    team2_count = gatherers.team(2).count
    pick_plan.slot_available?(turn: turn, team1_count: team1_count, team2_count: team2_count)
  end

  def bump_version!
    with_lock do
      update!(version: version.to_i + 1)
    end
  end

  def can_create?(cuser)
    true if cuser.admin? || cuser.gather_moderator?
  end

  def can_update?(cuser)
    true if cuser.admin? || cuser.gather_moderator?
  end

  def admin_update(attributes)
    updated = with_lock do
      admin_attributes = prepare_admin_attributes(attributes)
      next false unless update(admin_attributes)

      assign_captain_teams if saved_change_to_captain1_id? || saved_change_to_captain2_id?
      true
    end
    Gathers::Broadcaster.call(self) if updated
    updated
  end

  private

  def initialize_state
    self.status = STATE_RUNNING
  end

  def populate_maps_and_servers
    category.maps.basic.classic.each { |map| maps << map }

    available_servers = category_id == 44 ? category.servers.hlds.active.ordered : category.servers.active.ordered
    available_servers.each { |available_server| servers << available_server }
  end

  def pick_strategy_immutable
    changed = if respond_to?(:will_save_change_to_pick_strategy?)
                will_save_change_to_pick_strategy?
              else
                pick_strategy_changed?
              end
    errors.add(:pick_strategy, 'cannot be changed') if changed
  end

  def refresh_voting
    return unless voting_expired?

    with_lock do
      complete_voting! if status == STATE_VOTING && voting_expired?
    end
  end

  def voting_expired?
    voting_start_time && Time.current > voting_start_time + voting_timeout.seconds
  end

  def complete_voting!
    create_follow_up_gather
    ordered_maps = gather_maps.ordered.limit(2).to_a
    update!(
      picking_state_attributes.merge(
        captain1: gatherers.most_voted[1],
        captain2: gatherers.most_voted[0],
        map1: ordered_maps[0],
        map2: ordered_maps[1],
        server: gather_servers.ordered.first&.server
      )
    )
    assign_captain_teams
  end

  def create_follow_up_gather
    category&.with_lock do
      Gather.create!(category: category) unless Gather.where(category_id: category_id).where('id > ?', id).exists?
    end
  end

  def assign_captain_teams
    captain1&.update!(team: 1, pick_order: 1, skip_callbacks: true)
    captain2&.update!(team: 2, pick_order: 2, skip_callbacks: true)

    gatherers.where.not(id: [captain1_id, captain2_id]).find_each do |gatherer|
      gatherer.update!(team: nil, pick_order: nil, skip_callbacks: true)
    end
  end

  def picking_state_attributes
    { status: STATE_PICKING, turn: 1 }
  end

  def refresh_picking
    team1_count = gatherers.team(1).count
    team2_count = gatherers.team(2).count
    return unless pick_plan.transition(current_turn: turn, team1_count: team1_count, team2_count: team2_count)

    with_lock do
      team1_count = gatherers.team(1).count
      team2_count = gatherers.team(2).count
      transition = pick_plan.transition(
        current_turn: turn,
        team1_count: team1_count,
        team2_count: team2_count
      )
      apply_picking_transition(transition)
    end
  end

  def pick_plan
    Gathers::PickPlan.new(strategy: pick_strategy, team_size: FULL / 2)
  end

  def apply_picking_transition(transition)
    case transition
    when :finish
      update!(status: STATE_FINISHED)
    when :team_one
      update!(turn: 1)
    when :team_two
      update!(turn: 2)
    when :fill_team_two
      gatherers.lobby.first&.update!(team: 2, skip_callbacks: true)
      update!(turn: 2)
    end
  end

  # Prepares admin attributes for updating the gather, ensuring that if
  # captains are changed, the picking state is also updated.
  def prepare_admin_attributes(attributes)
    attributes = attributes.to_h.symbolize_keys
    captain_changed = %i[captain1_id captain2_id].any? do |key|
      attributes.key?(key) && attributes[key].to_i != public_send(key).to_i
    end
    attributes.merge!(picking_state_attributes) if captain_changed
    attributes
  end
end
