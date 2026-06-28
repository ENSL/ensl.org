# frozen_string_literal: true

# == Schema Information
#
# Table name: teamers
#
#  id         :integer          not null, primary key
#  comment    :string(255)
#  rank       :integer          not null
#  created_at :datetime
#  updated_at :datetime
#  team_id    :integer          not null
#  user_id    :integer          not null
#
# Indexes
#
#  index_teamers_on_team_id  (team_id)
#  index_teamers_on_user_id  (user_id)
#

class Teamer < ApplicationRecord
  include Extra

  RANK_REMOVED = -2
  RANK_JOINER = -1
  RANK_MEMBER = 0
  RANK_DEPUTEE = 1
  RANK_LEADER = 2

  # attr_protected :id, :created_at, :updated_at, :version

  validates :comment, length: { in: 0..15, allow_blank: true }
  validates :user, :team, presence: true
  # validate_on_create:validate_team
  # validate_on_create:validate_contests
  validate :validate_team

  scope :basic, -> { includes(:user).order('rank DESC, created_at ASC') }
  scope :past, -> { where('teamers.rank = ?', RANK_REMOVED) }
  scope :joining, -> { where('teamers.rank = ?', RANK_JOINER) }
  scope :present, -> { where('teamers.rank >= ?', RANK_JOINER) }
  scope :active, -> { where('teamers.rank >= ?', RANK_MEMBER) }
  scope :leaders, -> { where('teamers.rank >= ?', RANK_DEPUTEE) }
  scope :of_team, ->(team) { where('teamers.team_id' => team.id) }
  scope :active_teams, -> { includes(:team).where(teams: { active: true }) }
  scope :unique_by_team, -> { group('user_id, team_id') }
  scope :ordered, -> { order('rank DESC, created_at ASC') }
  scope :historic, lambda { |user, time|
    where('user_id = ? AND created_at < ? AND ((updated_at > ? AND rank = ?) OR rank >= ?)',
          user.id, time.utc, time.utc, RANK_REMOVED, RANK_MEMBER)
  }

  belongs_to :user, optional: true
  belongs_to :team, optional: true
  has_many :other_teamers, ->(teamer) { where('teamers.id != ?', teamer.id) }, through: :user, source: :teamers
  has_many :contesters, through: :team

  before_create :init_variables

  delegate :to_s, to: :user

  def ranks
    { RANK_JOINER => 'Joining', RANK_MEMBER => 'Member', RANK_DEPUTEE => 'Deputee', RANK_LEADER => 'Leader' }
  end

  def rank_s
    ranks[rank]
  end

  def validate_team
    return unless user && team

    # Allow historical re-joins, but do not allow multiple current memberships/applications.
    return unless Teamer.where(user_id: user.id, team_id: team.id)
                        .where('rank >= ?', RANK_JOINER)
                        .where.not(id: id)
                        .exists?

    errors.add :team, I18n.t(:teams_join_twice)
  end

  def validate_contests
    # TODO
  end

  def init_variables
    self.rank = RANK_JOINER unless rank
  end

  # rubocop:disable Rails/ActiveRecordOverride
  # NOTE: This custom destroy preserves historical rows for non-joiners by marking
  # them as removed instead of deleting them from the database.
  def destroy
    transaction do
      user.update!(team_id: nil) if user && user.team_id == team_id

      return super if rank == Teamer::RANK_JOINER

      update!(rank: Teamer::RANK_REMOVED)
    end
  end
  # rubocop:enable Rails/ActiveRecordOverride

  def can_create?(cuser, params)
    cuser and Verification.contain params, %i[user_id team_id]
  end

  def can_update?(cuser)
    cuser&.admin?
  end

  def can_destroy?(cuser)
    cuser and (user == cuser or team.is_leader? cuser or cuser.admin?)
  end

  def submit_for_actor(actor)
    return false unless actor

    self.user = actor unless actor.admin?
    old_application = actor.teamers.joining.first
    saved = save
    old_application&.destroy if saved
    saved
  end

  def self.params(params, _cuser)
    params.require(:teamer).permit(:comment, :rank, :team_id, :user_id)
  end

  def self.build_for_actor(params, actor)
    teamer_params = self.params(params, actor)
    teamer = new(teamer_params)
    [teamer, teamer_params]
  end
end
