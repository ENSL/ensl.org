# frozen_string_literal: true

module Gathers
  class PickPlan
    DEFAULT_STRATEGY = '1-2-2-2-2-1'
    DEFAULT_PICK_SIZES = [1, 2, 2, 2, 2, 1].freeze
    STRATEGIES = {
      DEFAULT_STRATEGY => DEFAULT_PICK_SIZES,
      '1-1-1-1' => [1, 1, 1, 1].freeze,
      'team_pick' => DEFAULT_PICK_SIZES,
      'random' => DEFAULT_PICK_SIZES,
      'gather_rank' => DEFAULT_PICK_SIZES,
      'ml_rank' => DEFAULT_PICK_SIZES
    }.freeze

    def initialize(strategy:, team_size:)
      @pick_sizes = STRATEGIES.fetch(strategy, DEFAULT_PICK_SIZES)
      @team_size = team_size
      @total_picks = (team_size * 2) - 2
      @picking_teams = build_picking_teams.freeze
    end

    def transition(current_turn:, team1_count:, team2_count:)
      return :finish if team1_count == @team_size && team2_count == @team_size

      completed_picks = completed_picks(team1_count, team2_count)
      next_team = @picking_teams[completed_picks]
      previous_team = @picking_teams[completed_picks - 1] if completed_picks.positive?
      return if next_team.nil? || next_team == current_turn || previous_team != current_turn
      return :fill_team_two if completed_picks == @total_picks - 1

      next_team == 1 ? :team_one : :team_two
    end

    def slot_available?(turn:, team1_count:, team2_count:)
      @picking_teams[completed_picks(team1_count, team2_count)] == turn
    end

    private

    def completed_picks(team1_count, team2_count)
      [team1_count - 1, 0].max + [team2_count - 1, 0].max
    end

    def build_picking_teams
      picking_teams = []
      team = 1

      @pick_sizes.cycle do |pick_size|
        remaining_picks = @total_picks - picking_teams.length
        picking_teams.concat([team] * [pick_size, remaining_picks].min)
        break if picking_teams.length == @total_picks

        team = team == 1 ? 2 : 1
      end

      picking_teams
    end
  end
end
