# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Round do
  describe '#observed_teams' do
    let(:round) { Round.create!(server_name: 'ENSL Server One', start_time: Time.zone.parse('2026-01-01 12:00:00')) }

    def player_raw(name, steamid, team)
      "\"#{name}<1><#{steamid}><#{team}>\""
    end

    it 'tallies each steamid\'s team suffix seen across the round\'s log lines' do
      LogLine.create!(round: round, event_type: 'role_change', param1: 'soldier', actor_steamid: 'STEAM_0:1:1',
                      raw_text: player_raw('MarineOne', 'STEAM_0:1:1', 'marine1team'),
                      created_at: round.start_time + 5.seconds)
      LogLine.create!(round: round, event_type: 'role_change', param1: 'skulk', actor_steamid: 'STEAM_0:1:1',
                      raw_text: player_raw('MarineOne', 'STEAM_0:1:1', 'marine1team'),
                      created_at: round.start_time + 10.seconds)
      LogLine.create!(round: round, event_type: 'kill', actor_steamid: 'STEAM_0:1:2', target_steamid: 'STEAM_0:1:1',
                      raw_text: "#{player_raw('AlienOne', 'STEAM_0:1:2', 'alien1team')} killed " \
                                "#{player_raw('MarineOne', 'STEAM_0:1:1', 'marine1team')} with \"bitegun\"",
                      created_at: round.start_time + 15.seconds)

      teams = round.observed_teams

      expect(teams['STEAM_0:1:1']).to eq('marine' => 3)
      expect(teams['STEAM_0:1:2']).to eq('alien' => 1)
    end

    it 'ignores tokens with neither a marine nor alien team suffix' do
      LogLine.create!(round: round, event_type: 'disconnect', actor_steamid: 'STEAM_0:1:1',
                      raw_text: player_raw('MarineOne', 'STEAM_0:1:1', 'none'),
                      created_at: round.start_time + 5.seconds)

      expect(round.observed_teams['STEAM_0:1:1']).to be_blank
    end

    it 'is memoized on the Round instance so repeated calls do not rescan log lines' do
      LogLine.create!(round: round, event_type: 'role_change', param1: 'soldier', actor_steamid: 'STEAM_0:1:1',
                      raw_text: player_raw('MarineOne', 'STEAM_0:1:1', 'marine1team'),
                      created_at: round.start_time + 5.seconds)

      round.observed_teams
      expect(round.log_lines).not_to receive(:find_each)
      round.observed_teams
    end
  end
end
