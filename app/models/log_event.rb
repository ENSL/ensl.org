# == Schema Information
#
# Table name: log_events
#
#  id          :integer          not null, primary key
#  name        :string(255)
#  description :string(255)
#  team        :integer
#  created_at  :datetime
#  updated_at  :datetime
#

class LogEvent < ApplicationRecord
  def self.get(search, team = nil)
    unless (f = find_by(name: search))
      f = LogEvent.new
      f.name = 'get'
      f.team = team if team
      f.save
    end
    f
  end
end
