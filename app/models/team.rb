# frozen_string_literal: true

# == Schema Information
#
# Table name: teams
#
#  id            :integer          not null, primary key
#  active        :boolean          default(TRUE), not null
#  comment       :string(255)
#  country       :string(255)
#  irc           :string(255)
#  logo          :string(255)
#  name          :string(255)
#  recruiting    :string(255)
#  tag           :string(255)
#  teamers_count :integer
#  web           :string(255)
#  created_at    :datetime
#  updated_at    :datetime
#  founder_id    :integer
#
# Indexes
#
#  index_teams_on_founder_id  (founder_id)
#

class Team < ApplicationRecord
  include Extra

  LOGOS = 'logos'
  STATUS_INACTIVE = 0
  STATUS_ACTIVE = 1

  # attr_protected :id, :active, :founder_id, :created_at, :updated_at

  validates :name, :tag, presence: true
  validates :name, :tag, length: { in: 2..20 }
  validates :irc, length: { maximum: 60, allow_blank: true }
  validates :web, length: { maximum: 50, allow_blank: true }
  validates :country, format: { with: /\A[A-Z]{2}\z/, allow_blank: true }
  validates(*%i[comment recruiting], length: { in: 0..75, allow_blank: true })

  scope :with_teamers_num, lambda { |num|
    select('teams.*, COUNT(T.id) AS teamers_num')
      .joins("LEFT JOIN teamers T ON T.team_id = teams.id AND T.rank >= #{Teamer::RANK_MEMBER}")
      .group('teams.id')
      .having('teamers_num >= ?', num)
  }
  scope :non_empty_teams, -> { joins(:teamers).where("teamers.rank >= #{Teamer::RANK_MEMBER}").distinct }
  scope :with_teamers, -> { includes(:teamers) }
  scope :active, -> { where(active: true) }
  scope :inactive, -> { where(active: false) }
  scope :ordered, -> { order('name') }
  scope :recruiting, -> { where("recruiting IS NOT NULL AND recruiting != ''") }
  scope :not_in_contest, lambda { |contest|
    contest_id = contest.respond_to?(:id) ? contest.id : contest
    where.not(id: Contester.where(contest_id: contest_id).select(:team_id))
  }

  belongs_to :founder, class_name: 'User', optional: true

  has_many :active_teamers, -> { where('rank >= ?', Teamer::RANK_MEMBER) }, inverse_of: :team, dependent: :destroy
  has_many :teamers, dependent: :destroy, counter_cache: true
  has_many :leaders, -> { where('rank = ?', Teamer::RANK_LEADER) }, class_name: 'Teamer', inverse_of: :team,
                                                                    dependent: :destroy
  has_many :contesters, dependent: :destroy
  has_many :contests, -> { where('contesters.active', true) }, through: :contesters
  has_many :received_messages, class_name: 'Message', as: 'recipient', dependent: :destroy
  has_many :sent_messages, class_name: 'Message', as: 'sender', dependent: :destroy
  has_many :matches, through: :contesters
  has_many :matches_finished, -> { where('(score1 != 0 OR score2 != 0)') },
           through: :contesters, source: :matches
  has_many :matches_won, lambda {
    where('((score1 > score2 AND contester1_id = contesters.id) OR ' \
      '(score2 > score1 AND contester2_id = contesters.id)) AND ' \
        '(score1 != 0 OR score2 != 0)')
  },
           through: :contesters, source: :matches
  has_many :matches_lost, lambda {
    where('((score1 < score2 AND contester1_id = contesters.id) OR ' \
      '(score2 < score1 AND contester2_id = contesters.id)) AND ' \
        '(score1 != 0 OR score2 != 0)')
  },
           through: :contesters, source: :matches
  has_many :matches_draw, -> { where('(score1 = score2 AND score1 > 0) AND (score1 != 0 OR score2 != 0)') },
           through: :contesters, source: :matches

  mount_uploader :logo, TeamUploader

  before_create :init_variables
  after_create :add_leader

  def to_s
    name
  end

  def api_v1_payload
    {
      id: id,
      name: name,
      logo: logo,
      members: api_v1_members_payload
    }
  end

  def api_v1_members_payload
    teamers.active.map do |teamer|
      {
        id: teamer.user.id,
        username: teamer.user.username,
        steamid: teamer.user.steamid
      }
    end
  end

  def leaders_s
    leaders.join(', ')
  end

  def init_variables
    self.active = true
    self.recruiting = nil
    self.teamers_count = 0 if teamers_count.nil?
  end

  def add_leader
    return unless founder

    transaction do
      teamer = Teamer.create!(user: founder, team: self, rank: Teamer::RANK_LEADER)
      # set founder's team_id without invoking validations that may block assignment
      founder.update!(team_id: id)
      teamer
    end
  end

  def self.search(search)
    search ? where('LOWER(name) LIKE LOWER(?)', "%#{search}%") : all
  end

  def destroy
    has_matches = matches.count.positive?

    transaction do
      # rubocop:disable Rails/SkipsModelValidations
      User.where(team_id: id).update_all(team_id: nil)
      if has_matches
        update!(active: false)
        teamers.update_all(rank: Teamer::RANK_REMOVED)
      end
      # rubocop:enable Rails/SkipsModelValidations
    end

    # If no matches exist, destroy dependent associations then remove the record
    return if has_matches

    # Delete associated records directly to avoid association inverse counter-cache arithmetic
    Teamer.where(team_id: id).delete_all
    Contester.where(team_id: id).delete_all
    delete
  end

  def recover
    update(active: true)
  end

  def leader?(user)
    teamers.leaders.exists?(user_id: user.id)
  end

  alias is_leader? leader?

  def can_create?(cuser)
    cuser and !cuser.banned?(Ban::TYPE_MUTE)
  end

  def can_update?(cuser)
    cuser and (is_leader? cuser or cuser.admin?)
  end

  def can_destroy?(cuser)
    cuser&.admin?
  end

  def apply_member_rank_updates!(actor:, rank_params:, comment_params: nil)
    return if rank_params.blank?

    actor_rank = actor.teamers.active.of_team(self).first&.rank

    teamers.each do |member|
      new_rank_raw = rank_params[member.id.to_s]
      next if new_rank_raw.nil?

      new_rank = new_rank_raw.to_i
      next unless actor.admin? || (actor_rank && new_rank <= actor_rank)
      next if new_rank == Teamer::RANK_JOINER && member.rank != Teamer::RANK_JOINER

      promoted_from_joiner = member.rank == Teamer::RANK_JOINER && new_rank >= Teamer::RANK_MEMBER
      member.update(rank: new_rank, comment: comment_params&.[](member.id.to_s))
      member.user.update!(team_id: id) if promoted_from_joiner
    end
  end

  def self.params(params, _cuser)
    return {} unless params

    if params[:team].present?
      params.require(:team).permit!.except(:id, :active, :founder_id, :created_at, :updated_at)
    else
      {}
    end
  end
end
