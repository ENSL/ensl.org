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
