# frozen_string_literal: true

require 'rails_helper'

# Regression safety net for RoundsController#show's timeline query -- see
# app/controllers/rounds_controller.rb and /memories/repo/round-timeline.md.
RSpec.describe 'RoundsController', type: :request do
  describe 'GET /rounds' do
    let!(:matching_round) do
      Round.create!(server_name: 'ENSL One', map_name: 'ns_eclipse', start_time: Time.zone.parse('2026-03-14 12:00'),
                    end_time: Time.zone.parse('2026-03-14 12:12'), result: Round::RESULT_MARINE_WIN)
    end
    let!(:other_round) do
      Round.create!(server_name: 'ENSL Two', map_name: 'ns_veil', start_time: Time.zone.parse('2026-03-15 12:00'),
                    end_time: Time.zone.parse('2026-03-15 12:35'), result: Round::RESULT_ALIEN_WIN)
    end

    before do
      user = create(:user, username: 'ArchivePlayer', steamid: '0:1:12345')
      Rounder.create!(round: matching_round, steamid: "STEAM_#{user.steamid}", team: Rounder::TEAM_MARINES, share: 1)
      LogLine.create!(round: matching_round, raw_text: '"InGameNick<1><STEAM_0:1:12345><marine1team>"')
    end

    it 'filters rounds by registered user, Steam ID, nickname, duration, and date' do
      get '/rounds', params: { username: 'Archive', steamid: '12345', nickname: 'InGame', length: '10_to_20',
                               from: '2026-03-14', to: '2026-03-14' }

      expect(response).to have_http_status(:ok)
      expect(controller.instance_variable_get(:@rounds).map(&:id)).to eq([matching_round.id])
      expect(response.body).to include('50')
    end

    it 'lists rounds in chronological order and exposes map and server options' do
      get '/rounds'

      expect(response).to have_http_status(:ok)
      expect(controller.instance_variable_get(:@rounds).map(&:id)).to eq([matching_round.id, other_round.id])
      expect(response.body).to include('Any map', 'ns_eclipse', 'Any server', 'ENSL One')
    end
  end

  describe 'GET /rounds/calendar' do
    it 'shows the selected year with a link to that day in the archive' do
      Round.create!(server_name: 'ENSL One', start_time: Time.zone.parse('2026-03-14 12:00'))

      get '/rounds/calendar', params: { year: 2026 }

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('Round Calendar', 'March', 'from=2026-03-14')
    end
  end

  describe 'GET /rounds/statistics' do
    it 'groups rounds by their in-log start time, including empty months' do
      Round.create!(server_name: 'ENSL One', start_time: Time.zone.parse('2024-01-15 20:00'))
      Round.create!(server_name: 'ENSL Two', start_time: Time.zone.parse('2024-03-15 20:00'))
      Round.create!(server_name: 'ENSL Three', start_time: Time.zone.parse('2024-03-20 20:00'))
      Round.create!(server_name: 'No timestamp')

      get '/rounds/statistics'

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('Round Data Over Time', '3 recorded rounds', '2024 Q1', '3 rounds')
      months = controller.instance_variable_get(:@months)
      expect(months).to eq([
                             { date: Date.new(2024, 1, 1), count: 1 },
                             { date: Date.new(2024, 2, 1), count: 0 },
                             { date: Date.new(2024, 3, 1), count: 2 }
                           ])
    end

    it 'explains when the import has no round start times' do
      get '/rounds/statistics'

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('No round start times are available yet')
    end
  end

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

    it 'links to the chronologically adjacent rounds' do
      previous_round = Round.create!(server_name: 'ENSL Earlier', start_time: round.start_time - 1.hour)
      next_round = Round.create!(server_name: 'ENSL Later', start_time: round.start_time + 1.hour)

      get "/rounds/#{round.id}"

      expect(response.body).to include("/rounds/#{previous_round.id}", "/rounds/#{next_round.id}", 'Previous', 'Next')
    end
  end
end
