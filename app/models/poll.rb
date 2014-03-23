class Poll < ActiveRecord::Base
  include Extra

  attr_protected :id, :updated_at, :created_at, :votes, :user_id

  validates_length_of :question, :in => 1..50
  #validates_datetime :end_date

  belongs_to :user
  has_many :options, :class_name => "Option", :dependent => :destroy
  has_many :real_votes, :through => :options

  accepts_nested_attributes_for :options, :allow_destroy => true

  def voted? user
    real_votes.count(:conditions => {:user_id => user.id}) > 0
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
