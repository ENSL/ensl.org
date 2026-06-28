# frozen_string_literal: true

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

class GatherServer < ApplicationRecord
  scope :ordered, -> { order('votes DESC') }

  belongs_to :gather, optional: true
  belongs_to :server, optional: true
  has_many :real_votes, class_name: 'Vote', as: :votable, dependent: :destroy

  delegate :to_s, to: :server

  def before_create
    self.votes = 0
  end
end
