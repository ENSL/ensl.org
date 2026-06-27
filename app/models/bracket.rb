# frozen_string_literal: true

# == Schema Information
#
# Table name: brackets
#
#  id         :integer          not null, primary key
#  name       :string(255)
#  slots      :integer
#  created_at :datetime
#  updated_at :datetime
#  contest_id :integer
#
# Indexes
#
#  index_brackets_on_contest_id  (contest_id)
#

# Bracket model for contest brackets. Bracketers are the individual cells in the
# bracket, which can be linked to either a match or a contester (team).
# The model includes methods for managing the bracket structure.
class Bracket < ActiveRecord::Base
  include Extra

  MATCH_PATTERN = /\Amatch_(\d+)\z/
  CONTESTER_PATTERN = /\Acontester_(\d+)\z/
  SEPARATOR_PREFIX = '--'

  belongs_to :contest, optional: true
  has_many :bracketers, dependent: :destroy

  validates :contest_id, presence: true
  validates :name, presence: true, length: { minimum: 1 }
  validates :slots, presence: true, numericality: { only_integer: true, greater_than: 0 }

  def to_s
    name || format('Bracket #%d', id)
  end

  def get_bracketer(row, col)
    bracketers.pos(row, col).first || bracketers.create(row: row.to_i, column: col.to_i)
  end

  # Generates options for selecting matches and teams in the bracket cells.
  # Returns an array of arrays suitable for use in select dropdowns.
  def options
    ['-- Special'] +
      [%w[Empty empty], %w[Disabled disabled]] +
      ["#{SEPARATOR_PREFIX} Matches"] +
      contest.matches.map { |c| [c, "match_#{c.id}"] } +
      ["#{SEPARATOR_PREFIX} Teams"] +
      contest.contesters.map { |c| [c, "contester_#{c.id}"] }
  end

  # Returns the default value for a bracket cell at the given row and column.
  # The value indicates whether the cell is linked to a match or a contester (team).
  def default(row, col)
    b = bracketers.pos(row, col).first
    return nil unless b

    return 'disabled' if b.disabled
    return nil unless b.match_id || b.team_id

    b.match_id ? "match_#{b.match_id}" : "contester_#{b.team_id}"
  end

  # Updates the bracket cells based on the provided parameters.
  # Each cell can be linked to either a match or a contester (team).
  # Also handles disabled status and custom text for cells.
  def update_cells(params)
    return true if params.blank?

    params.each do |row, cols|
      # cols might be Hash or ActionController::Parameters
      next unless cols.respond_to?(:each)

      cols.each do |col, cell_value|
        b = get_bracketer(row, col)

        val_str = cell_value.to_s

        # Handle special values
        if val_str == 'empty'
          b.update(match_id: nil, team_id: nil, disabled: false, custom_text: nil)
        elsif val_str == 'disabled'
          b.update(match_id: nil, team_id: nil, disabled: true, custom_text: nil)
        elsif !val_str.blank? && !val_str.start_with?(SEPARATOR_PREFIX)
          attributes = parse_cell_value(val_str)
          if attributes
            update_hash = attributes.merge(disabled: false)
            b.update(update_hash)
          end
        end
      end
    end
    true
  end

  # Updates custom text for bracket cells
  def update_custom_text(params)
    return true if params.blank?

    params.each do |row, cols|
      next unless cols.respond_to?(:each)

      cols.each do |col, custom_text|
        b = get_bracketer(row, col)
        b.update(custom_text: custom_text.presence) if custom_text
      end
    end
    true
  end

  # Updates bracket attributes and bracket cell payload in one place.
  # Reuses existing cell update methods to avoid duplicated logic.
  def update_with_cells(params, cuser)
    payload = self.class.update_payload(params, cuser)

    transaction do
      return false unless update(payload[:bracket])

      update_cells(payload[:cell])
      update_custom_text(payload[:cell_custom])
    end

    true
  end

  def can_create?(cuser)
    cuser&.admin?
  end

  def can_update?(cuser)
    cuser&.admin?
  end

  def can_destroy?(cuser)
    cuser&.admin?
  end

  def self.params(params, _cuser)
    params.require(:bracket).permit(:contest_id, :slots, :name)
  end

  def self.update_payload(params, cuser)
    cell_params = params.permit(cell: {}, cell_custom: {})

    {
      bracket: self.params(params, cuser),
      cell: cell_params[:cell] || {},
      cell_custom: cell_params[:cell_custom] || {}
    }
  end

  private

  # Parses the value of a bracket cell to determine if it references a match or a contester (team).
  def parse_cell_value(value)
    case value
    when MATCH_PATTERN
      { match_id: value.match(MATCH_PATTERN)[1].to_i, team_id: nil }
    when CONTESTER_PATTERN
      { team_id: value.match(CONTESTER_PATTERN)[1].to_i, match_id: nil }
    end
  end
end
