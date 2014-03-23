class Week < ActiveRecord::Base
  include Extra

  attr_protected :id, :updated_at, :created_at

  validates_presence_of :contest, :map1, :map2
  validates_length_of :name, :in => 1..30

  scope :ordered, :order => "start_date ASC"

  belongs_to :contest
  belongs_to :map1, :class_name => "Map"
  belongs_to :map2, :class_name => "Map"
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
end
