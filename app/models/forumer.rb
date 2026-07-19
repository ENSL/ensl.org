# frozen_string_literal: true

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

class Forumer < ApplicationRecord
  ACCESS_READ = 0
  ACCESS_REPLY = 1
  ACCESS_TOPIC = 2

  include Extra

  validates :group_id, uniqueness: { scope: %i[forum_id access] }
  validates :group_id, :forum_id, presence: true
  validates :access, inclusion: { in: 0..2 }

  belongs_to :forum, optional: true
  belongs_to :group, optional: true

  before_create :init_variables

  def init_variables
    self.access ||= ACCESS_READ
  end

  delegate :accesses, to: :class

  def self.accesses
    { ACCESS_READ => 'Read', ACCESS_REPLY => 'Reply', ACCESS_TOPIC => 'Post a Topic' }
  end

  def self.params(params, _cuser)
    params.require(:forumer).permit(:access, :forum_id, :group_id)
  end
end
