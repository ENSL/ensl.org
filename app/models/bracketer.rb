# == Schema Information
#
# Table name: bracketers
#
#  id         :integer          not null, primary key
#  column     :integer
#  row        :integer
#  created_at :datetime
#  updated_at :datetime
#  bracket_id :integer
#  match_id   :integer
#  team_id    :integer
#
# Indexes
#
#  index_bracketers_on_match_id  (match_id)
#  index_bracketers_on_team_id   (team_id)
#

class Bracketer < ActiveRecord::Base
  include Exceptions
  include Extra

  # attr_protected :id, :updated_at, :created_at

  belongs_to :bracket, optional: true
  belongs_to :contest, optional: true
  belongs_to :match, optional: true
  belongs_to :contester, foreign_key: 'team_id', optional: true

  scope :pos, ->(row, col) { where(row: row, column: col) }

  def to_s
    if match_id
      return match.match_time.strftime('%H:%M %d/%b') unless match.match_time.past? and (match.score1 and match.score2)

      winner = match.score1 > match.score2 ? match.contester1.team : match.contester2.team
      "#{match.score1} - #{match.score2}"

    elsif contester
      contester.to_s[0, 10]
    end
  end
end
