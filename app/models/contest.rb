# == Schema Information
#
# Table name: contests
#
#  id           :integer          not null, primary key
#  contest_type :integer          default(0), not null
#  default_time :time
#  end          :datetime
#  modulus_3to1 :float(24)
#  modulus_4to0 :float(24)
#  modulus_base :integer
#  modulus_even :float(24)
#  name         :string(255)
#  short_name   :string(255)
#  start        :datetime
#  status       :integer
#  weight       :integer
#  created_at   :datetime
#  updated_at   :datetime
#  demos_id     :integer
#  rules_id     :integer
#  winner_id    :integer
#
# Indexes
#
#  index_contests_on_demos_id   (demos_id)
#  index_contests_on_rules_id   (rules_id)
#  index_contests_on_status     (status)
#  index_contests_on_winner_id  (winner_id)
#

class Contest < ActiveRecord::Base
  include Extra

  WEIGHT = 30.0
  STATUS_OPEN = 0
  STATUS_PROGRESS = 1
  STATUS_CLOSED = 3
  TYPE_LADDER = 0
  TYPE_LEAGUE = 1
  TYPE_BRACKET = 2

  scope :active, -> { where.not(status: STATUS_CLOSED) }
  scope :inactive, -> { where(status: STATUS_CLOSED) }
  scope :joinable, lambda {
    arel = arel_table
    where(arel[:status].eq(STATUS_OPEN).and(arel[:end].gt(Time.now.utc)))
  }
  scope :with_contesters, -> { includes(:contesters) }
  scope :ordered, -> { order('start DESC') }
  scope :nsls1, -> { where('name LIKE ?', 'NSL S1:%') }
  scope :nsls2, -> { where('name LIKE ?', 'NSL S2:%') }
  scope :ns1seasons, -> { where('name LIKE ?', 'S%:%') }

  has_many :matches, dependent: :destroy
  has_many :weeks, dependent: :destroy
  has_many :contesters, -> { includes(:team) }, dependent: :destroy
  has_many :predictions, through: :matches
  has_many :brackets
  has_many :preds_with_score, lambda {
    select("predictions.id, predictions.user_id,
          SUM(result) AS correct,
          SUM(result) * 1.0/COUNT(*) * 100 AS score,
          COUNT(*) AS total")
      .where('result IS NOT NULL')
      .group('predictions.user_id')
      .order('correct DESC')
  },
           source: :predictions,
           through: :matches
  has_and_belongs_to_many :maps
  belongs_to :demos, class_name: 'Directory', optional: true
  belongs_to :winner, class_name: 'Contester', optional: true
  belongs_to :rules, class_name: 'Article', optional: true

  validates_presence_of :name, :start, :end, :status, :default_time
  validates_length_of :name, in: 1..50
  validates_length_of :short_name, in: 1..8, allow_nil: true
  validate :validate_status
  validate :validate_contest_type

  def to_s
    name
  end

  def status_s
    statuses[status]
  end

  def default_s
    default_time ? default_time.strftime('%A %H:%M') : ''
  end

  def statuses
    { STATUS_OPEN => 'In Progress (signups open)', STATUS_PROGRESS => 'In Progress (signups closed)',
      STATUS_CLOSED => 'Closed' }
  end

  def types
    { TYPE_LADDER => 'Ladder', TYPE_LEAGUE => 'League', TYPE_BRACKET => 'Bracket' }
  end

  def validate_status
    errors.add :status, I18n.t(:invalid_status) unless statuses.include? status
  end

  def validate_contest_type
    errors.add :contest_type, I18n.t(:contests_invalidtype) unless types.include? contest_type
  end

  def recalculate
    Match.where(contest_id: id).update_all('diff = null, points1 = null, points2 = null')
    Contester.where(contest_id: id).update_all('score = 0, win = 0, loss = 0, draw = 0, extra = 0')
    matches.finished.chrono.each do |match|
      match.recalculate
      match.save
    end
  end

  def elo_score(score1, score2, diff, level = modulus_base, weight = self.weight,
                moduluses = [modulus_even, modulus_3to1, modulus_4to0])
    # Defensive defaults to avoid NaN / division by zero
    level = (level || modulus_base || 30).to_f
    weight = (weight || self.weight || WEIGHT).to_f
    weight = WEIGHT if weight <= 0.0

    moduluses ||= [modulus_even, modulus_3to1, modulus_4to0]
    moduluses = moduluses.map { |m| (m || 1.0).to_f }

    points = (score2 - score1).abs
    modulus = if points <= 1
                moduluses[0]
              elsif points == 2
                moduluses[1]
              else
                moduluses[2]
              end

    result = if score1 == score2
               0.5
             elsif score1 > score2
               1.0
             else
               0.0
             end

    prob = 1.0 / ((10**(diff.to_f / weight)) + 1.0)
    (level * modulus * (result - prob)).round
  end

  def update_ranks(contester, old_rank, new_rank)
    if old_rank < new_rank
      Contester.update_all(['score = score -1, trend = ?', Contester::TREND_UP],
                           ['contest_id = ? and score > ? and score <= ?',
                            id, old_rank, new_rank])
      contester.trend = Contester::TREND_DOWN
    elsif old_rank > new_rank
      Contester.update_all(['score = score + 1, trend = ?', Contester::TREND_DOWN],
                           ['contest_id = ? and score < ? and score >= ?',
                            id, old_rank, new_rank])
      contester.trend = Contester::TREND_UP
    end
    contester.score = new_rank
  end

  def ladder_ranks_unique?
    c = Contester.where({ contest_id: id })
    c.distinct.pluck(:score).count == c.count
  end

  def can_join?(cuser)
    cuser and !cuser&.banned?(Ban::TYPE_LEAGUE) and \
      cuser&.lead_teams&.not_in_contest(self)&.exists? and \
      Contest.joinable.where(id: id).exists?
  end

  def can_create?(cuser)
    cuser and cuser.admin?
  end

  def can_update?(cuser)
    cuser and cuser.admin?
  end

  def can_destroy?(cuser)
    cuser and cuser.admin?
  end

  def self.params(params, cuser)
    params.require(:contest).permit(:name, :start, :end, :status, :default_time,
                                    :contest_type, :winner_id, :demos_id, :short_name,
                                    :weight, :modulus_base, :modulus_even,
                                    :modulus_3to1, :modulus_4to0, :rules_id)
  end
end
