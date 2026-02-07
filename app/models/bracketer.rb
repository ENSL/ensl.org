# frozen_string_literal: true

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

# Model for a bracketer, which represents a position in a bracket.
# It can be associated with a match and a team (contester).
class Bracketer < ActiveRecord::Base
  include Exceptions
  include Extra

  belongs_to :bracket
  belongs_to :match, optional: true
  belongs_to :contester, foreign_key: 'team_id', optional: true

  scope :pos, ->(row, col) { where(row: row, column: col) }

  def to_s
    return match_display if match_id

    contester.to_s[0, 10] if contester
  end

  private

  def match_display
    # Show match time if match hasn't started or scores aren't complete
    return match.match_time.strftime('%H:%M %d/%b') unless match.match_time.past? && match.score1 && match.score2

    # Show score if match is finished
    "#{match.score1} - #{match.score2}"
  end
end
