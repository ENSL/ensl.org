# == Schema Information
#
# Table name: matchers
#
#  id           :integer          not null, primary key
#  merc         :boolean          not null
#  created_at   :datetime
#  updated_at   :datetime
#  contester_id :integer          not null
#  match_id     :integer          not null
#  user_id      :integer          not null
#
# Indexes
#
#  index_matchers_on_contester_id  (contester_id)
#  index_matchers_on_match_id      (match_id)
#  index_matchers_on_user_id       (user_id)
#

class Matcher < ActiveRecord::Base
  include Extra

  #attr_protected :id, :updated_at, :created_at

  belongs_to :match, :optional => true
  belongs_to :user, :optional => true
  belongs_to :contester, :optional => true
  has_many :teams, :through => :contester

  scope :stats, -> {
    select("user_id, COUNT(*) as num, users.username").
    joins("LEFT JOIN users ON users.id = user_id").
    group("user_id").
    having("num > 20").
    order("num DESC") }
  scope :mercs, -> { where(merc: true) }
  scope :of_contester, -> (contester) { where(contester_id: contester.id) }

  validates_presence_of :match, :user
  validates_uniqueness_of :user_id, :scope => :match_id
  validates_inclusion_of :merc, :in => [true, false]

end
