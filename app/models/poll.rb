# == Schema Information
#
# Table name: polls
#
#  id         :integer          not null, primary key
#  question   :string(255)
#  end_date   :datetime
#  user_id    :integer
#  created_at :datetime
#  updated_at :datetime
#  votes      :integer          default(0), not null
#

class Poll < ActiveRecord::Base
  include Extra

  default_scope -> { order("created_at DESC") }

  #attr_protected :id, :updated_at, :created_at, :votes, :user_id

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
