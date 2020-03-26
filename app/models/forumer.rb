# == Schema Information
#
# Table name: forumers
#
#  id         :integer          not null, primary key
#  access     :integer
#  created_at :datetime
#  updated_at :datetime
#  forum_id   :integer
#  group_id   :integer
#
# Indexes
#
#  index_forumers_on_forum_id  (forum_id)
#  index_forumers_on_group_id  (group_id)
#

class Forumer < ActiveRecord::Base
  ACCESS_READ = 0
  ACCESS_REPLY = 1
  ACCESS_TOPIC = 2

  include Extra

  scope :access, -> (level) { where("access >= ?", level) }

  validates_uniqueness_of :group_id, :scope => [:forum_id, :access]
  validates_presence_of [:group_id, :forum_id]
  validates_inclusion_of :access, :in => 0..2

  belongs_to :forum, :optional => true
  belongs_to :group, :optional => true

  before_create :init_variables

  def init_variables
    self.access ||= ACCESS_READ
  end

  def accesses
    {ACCESS_READ => "Read", ACCESS_REPLY => "Reply", ACCESS_TOPIC => "Post a Topic"}
  end

  def self.params(params, cuser)
    params.require(:forumer).permit(:access, :forum_id, :group_id)
  end
end
