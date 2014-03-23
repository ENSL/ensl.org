class Bracketer < ActiveRecord::Base
  include Exceptions
  include Extra

  attr_protected :id, :updated_at, :created_at

  belongs_to :contest
  belongs_to :match
  belongs_to :contester, :foreign_key => "team_id"

  scope :pos, lambda { |row, col| {:conditions => {"row" => row, "column" => col}} }

  def to_s
    if self.match_id
      if match.match_time.past? and (match.score1 and match.score2)
        winner = match.score1 > match.score2 ? match.contester1.team : match.contester2.team
        return "#{self.match.score1} - #{self.match.score2}"
      else
        return self.match.match_time.strftime("%H:%M %d/%b")
        end
    elsif self.contester
      return self.contester.to_s[0, 10]
    end
  end
end
