# == Schema Information
#
# Table name: weeks
#
#  id         :integer          not null, primary key
#  name       :string(255)
#  start_date :date
#  created_at :datetime
#  updated_at :datetime
#  contest_id :integer
#  map1_id    :integer
#  map2_id    :integer
#
# Indexes
#
#  index_weeks_on_contest_id  (contest_id)
#  index_weeks_on_map1_id     (map1_id)
#  index_weeks_on_map2_id     (map2_id)
#

class Week < ActiveRecord::Base
  include Extra

  #attr_protected :id, :updated_at, :created_at

  validates_presence_of :contest, :map1, :map2
  validates_length_of :name, :in => 1..30

  scope :ordered, -> { order("start_date ASC") }

  belongs_to :contest, :optional => true
  belongs_to :map1, :class_name => "Map", :optional => true
  belongs_to :map2, :class_name => "Map", :optional => true
  has_many :matches

  def to_s
    self.name
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

  def self.params(params, cuser)
    params.require(:week).permit(:name, :start_date, :contest_id, :map1_id, :map2_id)
  end
end
