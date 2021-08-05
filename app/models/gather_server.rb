# == Schema Information
#
# Table name: gather_servers
#
#  id         :integer          not null, primary key
#  votes      :integer
#  created_at :datetime
#  updated_at :datetime
#  gather_id  :integer
#  server_id  :integer
#

class GatherServer < ActiveRecord::Base
  scope :ordered, -> { order("votes DESC") }

  belongs_to :gather, :optional => true
  belongs_to :server, :optional => true
  has_many :real_votes, :class_name => "Vote", :as => :votable

  def to_s
    self.server.to_s
  end

  def before_create
    self.votes = 0
  end
end
