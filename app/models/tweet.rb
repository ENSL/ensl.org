class Tweet < ActiveRecord::Base
  include Extra

  scope :recent2, :order => "created_at DESC", :limit => 2
  scope :recent, :order => "created_at DESC", :limit => 5
  has_many :comments, :as => :commentable

  def to_s
    msg
  end
end
