# == Schema Information
#
# Table name: polls
#
#  id         :integer          not null, primary key
#  end_date   :datetime
#  question   :string(255)
#  votes      :integer          default("0"), not null
#  created_at :datetime
#  updated_at :datetime
#  user_id    :integer
#
# Indexes
#
#  index_polls_on_user_id  (user_id)
#

class Poll < ActiveRecord::Base
  include Extra

  default_scope -> { order("created_at DESC") }

  #attr_protected :id, :updated_at, :created_at, :votes, :user_id

  validates_length_of :question, :in => 1..50
  #validates_datetime :end_date

  belongs_to :user, :optional => true
  has_many :options, :class_name => "Option", :dependent => :destroy
  has_many :real_votes, :through => :options

  accepts_nested_attributes_for :options, :allow_destroy => true

  def voted? user
    real_votes.where(user_id: user.id).count > 0
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
    params.require(:poll).permit(:end_date, :question)
  end
end
