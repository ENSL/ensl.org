# == Schema Information
#
# Table name: groupers
#
#  id         :integer          not null, primary key
#  task       :string(255)
#  created_at :datetime
#  updated_at :datetime
#  group_id   :integer
#  user_id    :integer
#
# Indexes
#
#  index_groupers_on_group_id  (group_id)
#  index_groupers_on_user_id   (user_id)
#

class Grouper < ActiveRecord::Base
  #attr_protected :id, :created_at, :updated_at
  attr_accessor :username

  belongs_to :group, :optional => true
  belongs_to :user, :optional => true

  validates_associated :group, :user
  validates :group, :user, :presence => true
  validates :task, :length => {:maximum => 25}

  scope :valid_users, -> { joins(:user).where.not(users: { id: nil }) }

  before_validation :fetch_user, :if => Proc.new {|grouper| grouper.username and !grouper.username.empty?}

  def to_s
    user.to_s
  end

  def fetch_user
    self.user = User.find_by_username(username)
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
