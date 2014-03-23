class GatherMap < ActiveRecord::Base
  scope :ordered, :order => "votes DESC, id DESC"

  belongs_to :gather
  belongs_to :map
  has_many :real_votes, :class_name => "Vote", :as => :votable

  before_create :init_variables

  def to_s
    self.map.to_s
  end

  def init_variables
    self.votes = 0
  end
end
