# == Schema Information
#
# Table name: gather_maps
#
#  id        :integer          not null, primary key
#  votes     :integer
#  gather_id :integer
#  map_id    :integer
#
# Indexes
#
#  index_gather_maps_on_gather_id  (gather_id)
#  index_gather_maps_on_map_id     (map_id)
#

class GatherMap < ActiveRecord::Base
  scope :ordered, -> { order("votes DESC, id DESC") }

  belongs_to :gather, :optional => true
  belongs_to :map, :optional => true
  has_many :real_votes, :class_name => "Vote", :as => :votable

  before_create :init_variables

  def to_s
    self.map.to_s
  end

  def init_variables
    self.votes = 0
  end
end
