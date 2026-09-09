# frozen_string_literal: true

# Groups rounds by the alien team's distinct chamber choices. In NS1 a hive
# locks its chamber type when the first chamber is built, so duplicate builds
# do not represent an additional tech choice.
class AlienTechPathQuery < MarineTechPathQuery
  CHAMBERS = %w[defensechamber movementchamber sensorychamber].freeze

  private

  def research_events
    Round.where.not(result: nil)
         .joins(:log_lines)
         .where(log_lines: { event_type: 'structure_built', param1: CHAMBERS })
         .order('log_lines.created_at', 'log_lines.id')
         .pluck('log_lines.round_id', 'log_lines.param1')
  end

  def winning_result?(result)
    result == Round::RESULT_ALIEN_WIN
  end
end
