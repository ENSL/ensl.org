# frozen_string_literal: true

# == Schema Information
#
# Table name: rounders
#
#  id       :integer          not null, primary key
#  round_id :integer
#  user_id  :integer
#  team     :integer
#  roles    :string(255)
#  kills    :integer
#  deaths   :integer
#  name     :string(255)
#  steamid  :string(255)
#  team_id  :integer
#

class Rounder < ApplicationRecord
  attr_accessor :lifeform

  scope :team, ->(team) { where(team: team) }
  scope :match, ->(steamid) { where(steamid: steamid) }
  scope :ordered, -> { order('kills DESC, deaths ASC') }
  scope :stats,
        lambda {
          select('id, team_id, COUNT(*) as num')
            .group('team_id')
            .order('num DESC')
            .having('num > 3')
        }
  scope :extras, -> { includes(:round, :user) }
  scope :within,
        ->(from, to) { where('created_at > ? AND created_at < ?', from.utc, to.utc) }

  belongs_to :round
  belongs_to :user
  belongs_to :ensl_team, class_name: 'Team', foreign_key: 'team_id'

  def to_s
    user ? user.username : name
  end
end
