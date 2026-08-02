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
class Bracketer < ApplicationRecord
  include Exceptions
  include Extra

  belongs_to :bracket
  belongs_to :match, optional: true
  belongs_to :contester, foreign_key: 'team_id', optional: true, inverse_of: :bracketers

  scope :pos, ->(row, col) { where(row: row, column: col) }

  # Returns the CSS class for match result: "win1", "win2", "tie", or nil
  # Determines result by looking at the NEXT column in the bracket structure
  # to see which team/match advanced, rather than searching all contest matches.
  def result_class
    return nil if disabled

    advancing_id = effective_contester_id
    return nil unless advancing_id

    next_cell = next_round_cell
    return nil if next_cell.nil? || next_cell.disabled

    if next_cell.team_id
      next_cell.team_id == advancing_id ? 'win1' : 'win2'
    elsif next_cell.match_id
      result_from_match(next_cell.match_id, advancing_id)
    end
  end

  def to_s
    return match_display if match_id

    contester.to_s[0, 10] if contester
  end

  private

  def result_from_match(match_id, advancing_id)
    next_match = Match.find_by(id: match_id)
    return nil unless next_match&.score1 && next_match.score2

    scores = scores_for(next_match, advancing_id)
    score_result(*scores) if scores
  end

  def scores_for(next_match, advancing_id)
    if next_match.contester1_id == advancing_id
      [next_match.score1, next_match.score2]
    elsif next_match.contester2_id == advancing_id
      [next_match.score2, next_match.score1]
    end
  end

  def score_result(advancing_score, opposing_score)
    case advancing_score <=> opposing_score
    when 1 then 'win1'
    when -1 then 'win2'
    else 'tie'
    end
  end

  # Returns the contester ID that this cell effectively represents.
  # For team cells: the team_id (which is actually a contester_id).
  # For match cells: the winner of the match (if scores exist).
  def effective_contester_id
    if team_id
      team_id
    elsif match_id
      m = Match.find_by(id: match_id)
      return nil unless m
      return nil if m.score1.nil? || m.score2.nil?

      if m.score1 > m.score2
        m.contester1_id
      elsif m.score2 > m.score1
        m.contester2_id
      end
      # Tie → no clear winner → nil
    end
  end

  # Finds the bracket cell in the next column that this cell feeds into.
  # Uses the bracket's binary tree structure to calculate the target position.
  def next_round_cell
    next_exp = 2**(column + 2)
    result_row = (row / next_exp) * next_exp + next_exp / 2
    bracket.bracketers.pos(result_row, column + 1).first
  end

  def match_display
    # Show match time if match hasn't started or scores aren't complete
    return match.match_time.strftime('%H:%M %d/%b') unless match.match_time.past? && match.score1 && match.score2

    # Show score if match is finished
    "#{match.score1} - #{match.score2}"
  end
end
