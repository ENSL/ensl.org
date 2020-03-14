# == Schema Information
#
# Table name: groups
#
#  id         :integer          not null, primary key
#  name       :string(255)
#  created_at :datetime
#  updated_at :datetime
#  founder_id :integer
#

class Group < ActiveRecord::Base
  include Extra

  ADMINS = 1
  REFEREES = 2
  MOVIES = 3
  DONORS = 4
  MOVIEMAKERS = 5
  CASTERS = 6
  CHAMPIONS = 7
  PREDICTORS = 8
  STAFF = 10
  GATHER_MODERATORS = 14
  CONTRIBUTORS = 16

  attr_protected :id, :updated_at, :created_at, :founder_id
  validates_length_of :name, :maximum => 20

  has_and_belongs_to_many :users
  has_many :groupers
  has_many :users, :through => :groupers
  belongs_to :founder, :class_name => "User"

  def to_s
    name
  end

  def can_create? cuser
    cuser and cuser.admin?
  end

  def can_update? cuser
    cuser and cuser.admin?
  end

  def can_destroy? cuser
    cuser and cuser.admin? and id != Group::ADMINS
  end

  def self.staff
    staff = []

    (admins + casters + referees + extras).each do |g|
      staff << g unless staff.include? g
    end
    staff
  end

  def self.admins
    find(ADMINS).groupers.valid_users
  end

  def self.referees
    referees = []
    referee_group = where(id: REFEREES).firsto
    return referees unless referee_group

    (referee_group.groupers).each do |g|
      referees << g unless referees.include? g
    end
    referees
  end

  def self.extras
    extras = []
    extra_group = where(id: PREDICTORS).first
    staff_group = where(id: STAFF).first

    extra_groupers = extra_group ? extra_group.groupers : []
    staff_groupers = staff_group ? staff_group.groupers : []

    (extra_groupers + staff_groupers).each do |g|
      extras << g unless extras.include? g
    end
    extras
  end

  def self.casters
    casters = []
    caster_group = where(id:CASTERS).first
    return casters unless caster_group

    (caster_group.groupers).each do |g|
      casters << g unless casters.include? g
    end
    casters
  end

  def self.gathermods
    gathermods = []
    gathermod_group = where(id:GATHER_MODERATORS).first
    return gathermods unless gathermod_group

    (gathermod_group.groupers).each do |g|
      gathermods << g unless gathermods.include? g
    end
    gathermods
  end

  def self.contributors
    contributors = []
    group_contrib = where(id:CONTRIBUTORS).first
    return contributors unless group_contrib

    (group_contrib.groupers).each do |g|
      contributors << g unless contributors.include? g
    end
    contributors
  end
end
