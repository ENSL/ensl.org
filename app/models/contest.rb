# == Schema Information
#
# Table name: contests
#
#  id           :integer          not null, primary key
#  name         :string(255)
#  start        :datetime
#  end          :datetime
#  status       :integer
#  created_at   :datetime
#  updated_at   :datetime
#  default_time :time
#  contest_type :integer          default(0), not null
#  winner_id    :integer
#  demos_id     :integer
#  short_name   :string(255)
#  weight       :integer
#  modulus_base :integer
#  modulus_even :float
#  modulus_3to1 :float
#  modulus_4to0 :float
#  rules_id     :integer
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

  #attr_protected :id, :updated_at, :created_at

  scope :active, -> { where.not(status: STATUS_CLOSED) }
  scope :inactive, -> { where(status: STATUS_CLOSED) }
  scope :joinable, -> { where(status: STATUS_OPEN) }
  scope :with_contesters, -> { includes(:contesters) }
  scope :ordered, -> { order("start DESC") }
  scope :nsls1, -> { where("name LIKE ?", "NSL S1:%") }
  scope :nsls2, -> { where("name LIKE ?", "NSL S2:%") }
  scope :ns1seasons, -> { where("name LIKE ?", "S%:%") }

  has_many :matches, :dependent => :destroy
  has_many :weeks, :dependent => :destroy
  has_many :contesters, -> { includes(:team) }, :dependent => :destroy
  has_many :predictions, :through => :matches
  has_many :brackets
  has_many :preds_with_score, -> {
            select("predictions.id, predictions.user_id
                    SUM(result) AS correct,
                    SUM(result)/COUNT(*)*100 AS score,
                    COUNT(*) AS total")
            .where("result IS NOT NULL")
            .group("predictions.user_id")
            .order("correct DESC") },
            :source => :predictions,
            :through => :matches
  has_and_belongs_to_many :maps
  belongs_to :demos, :class_name => "Directory"
  belongs_to :winner, :class_name => "Contester"
  belongs_to :rules, :class_name => "Article"

  validates_presence_of :name, :start, :end, :status, :default_time
  validates_length_of :name, :in => 1..50
  validates_length_of :short_name, :in => 1..8, :allow_nil => true
  validate :validate_status
  validate :validate_contest_type

  def to_s
    name
  end

  def status_s
    statuses[status]
  end

  def default_s
    "Sunday " + default_time.to_s
  end

  def statuses
    {STATUS_OPEN => "In Progress (signups open)", STATUS_PROGRESS => "In Progress (signups closed)", STATUS_CLOSED => "Closed"}
  end

  def types
    {TYPE_LADDER => "Ladder", TYPE_LEAGUE => "League", TYPE_BRACKET => "Bracket"}
  end

  def validate_status
    errors.add :status, I18n.t(:invalid_status) unless statuses.include? status
  end

  def validate_contest_type
    errors.add :contest_type, I18n.t(:contests_invalidtype) unless types.include? contest_type
  end

  def recalculate
    Match.update_all("diff = null, points1 = null, points2 = null", {:contest_id => self.id})
    Contester.update_all("score = 0, win = 0, loss = 0, draw = 0, extra = 0", {:contest_id => self.id})
    matches.finished.chrono.each do |match|
      match.recalculate
      match.save
    end
  end

  def update_ranks contester, old_rank, new_rank
    if old_rank < new_rank
      Contester.update_all(["score = score -1, trend = ?", Contester::TREND_UP],
                           ["contest_id = ? and score > ? and score <= ?",
                            self.id, old_rank, new_rank])
      contester.trend = Contester::TREND_DOWN
    elsif old_rank > new_rank
      Contester.update_all(["score = score + 1, trend = ?", Contester::TREND_DOWN],
                           ["contest_id = ? and score < ? and score >= ?",
                            self.id, old_rank, new_rank])
      contester.trend = Contester::TREND_UP
    end
    contester.score = new_rank
  end

  def ladder_ranks_unique?
    c = Contester.where({:contest_id => self.id})
    c.uniq.pluck(:score).count == c.count
  end


  def can_create? cuser
    cuser and cuser.admin?
  end

  def can_update? cuser
    cuser and cuser.admin?
  end

  def can_destroy? cuser
    cuser and cuser.admin?
  end
end
