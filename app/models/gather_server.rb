class GatherServer < ActiveRecord::Base
  scope :ordered, :order => "votes DESC"

  belongs_to :gather
  belongs_to :server
  has_many :real_votes, :class_name => "Vote", :as => :votable

  def to_s
    self.server.to_s
  end

  def before_create
    self.votes = 0
  end
end
