# == Schema Information
#
# Table name: tweets
#
#  id         :integer          not null, primary key
#  msg        :string(255)
#  link       :string(255)
#  created_at :datetime
#  updated_at :datetime
#

class Tweet < ActiveRecord::Base
  include Extra

  scope :recent2, :order => "created_at DESC", :limit => 2
  scope :recent, :order => "created_at DESC", :limit => 5
  has_many :comments, :as => :commentable

  def to_s
    msg
  end
end
