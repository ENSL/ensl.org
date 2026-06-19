# frozen_string_literal: true

module BracketsHelper
  # Returns the full CSS class string for a bracket cell's <td>
  def bracket_cell_class(bracket, bracketer, row, col, cols, is_edit_mode)
    exp = 2**(col + 1)

    if (row % exp) == exp / 2
      classes = ['team']
      if !is_edit_mode && bracketer&.disabled
        classes << 'disabled'
      elsif !is_edit_mode
        result = bracketer&.result_class
        classes << result if result
      end
      classes.join(' ')
    elsif render_connector?(bracket, row, col, cols, is_edit_mode)
      'connector'
    else
      'empty'
    end
  end

  # Is this cell a team position?
  def bracket_cell_team?(row, col)
    exp = 2**(col + 1)
    (row % exp) == exp / 2
  end

  # Should content be shown for this cell in view mode?
  def bracket_show_content?(bracketer)
    bracketer && !bracketer.disabled
  end

  private

  # Determines if a connector cell should be rendered at given row/col
  def render_connector?(bracket, row, col, cols, is_edit_mode)
    exp = 2**(col + 1)
    is_connector_pos = col < cols - 1 && (((row + exp / 2) - (row + exp / 2) % exp) / exp).odd?

    return is_connector_pos if is_edit_mode
    return false unless is_connector_pos

    group = (row + exp / 2) / exp
    team_above_row = group * exp - exp / 2
    team_below_row = group * exp + exp / 2

    # Check if the cells at these positions exist and are not disabled
    # Use pos scope to avoid auto-creating cells
    above_cell = bracket.bracketers.pos(team_above_row, col).first
    below_cell = bracket.bracketers.pos(team_below_row, col).first

    # Only render connector if both cells exist and neither is disabled
    above_cell && below_cell && !above_cell.disabled && !below_cell.disabled
  end
end
