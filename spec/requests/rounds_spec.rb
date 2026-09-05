# frozen_string_literal: true

require 'rails_helper'

# Regression safety net for RoundsController#show's timeline query -- see
# app/controllers/rounds_controller.rb and /memories/repo/round-timeline.md.
RSpec.describe 'RoundsController', type: :request do
  describe 'GET /rounds/:id' do
    let(:round) do
      Round.create!(
        server_name: 'ENSL Server One',
        map_name: 'ns_eclipse',
        start_time: Time.zone.parse('2026-01-01 12:00:00'),
        end_time: Time.zone.parse('2026-01-01 12:20:00'),
        result: Round::RESULT_MARINE_WIN
      )
    end

    it 'excludes attacked/player_acts noise and anything before round start' do
      before_start = LogLine.create!(round: round, event_type: 'join_team', actor_steamid: 'STEAM_0:1:1',
                                     created_at: round.start_time - 1.minute)
      attacked = LogLine.create!(round: round, event_type: 'attacked', actor_steamid: 'STEAM_0:1:1',
                                 created_at: round.start_time + 10.seconds)
      player_acts = LogLine.create!(round: round, event_type: 'player_acts', actor_steamid: 'STEAM_0:1:1',
                                    created_at: round.start_time + 10.seconds)
      kept = LogLine.create!(round: round, event_type: 'round_start', created_at: round.start_time)

      get "/rounds/#{round.id}"

      expect(response).to have_http_status(:ok)
      log_lines = controller.instance_variable_get(:@log_lines)
      expect(log_lines).to contain_exactly(kept)
      expect(log_lines).not_to include(before_start, attacked, player_acts)
    end
  end
end
