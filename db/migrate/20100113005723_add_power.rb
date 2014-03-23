class AddPower < ActiveRecord::Migration
  def self.up
  	User.all.each do |user|
  		if user.team
  			user.update_attribute :team_id, nil unless user.active_teams.include? user.team
  		end
  	end
  end

  def self.down
  end
end