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

class LogEvent < ActiveRecord::Base
  def self.get search, team = nil
    if f = first({:conditions => {:name => search}})
      return f
    else
      f = LogEvent.new
      f.name = "get"
      f.team = team if team
      f.save
      return f
    end
  end
end
