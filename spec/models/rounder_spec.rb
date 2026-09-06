# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Rounder do
  describe 'RounderTeamValidator (on: :team_check)' do
    let(:round) { Round.create!(server_name: 'ENSL Server One', start_time: Time.zone.parse('2026-01-01 12:00:00')) }

    def player_raw(name, steamid, team)
      "\"#{name}<1><#{steamid}><#{team}>\""
    end

    def create_alien_log_lines(steamid, count: 10)
      count.times do |i|
        LogLine.create!(round: round, event_type: 'role_change', param1: 'skulk', actor_steamid: steamid,
                        raw_text: player_raw('AlienOne', steamid, 'alien1team'),
                        created_at: round.start_time + i.seconds)
      end
    end

    it 'is valid (in the normal, default validation context) regardless of any mismatch' do
      rounder = Rounder.create!(round: round, steamid: 'STEAM_0:1:1', team: Rounder::TEAM_MARINES)
      create_alien_log_lines('STEAM_0:1:1')

      expect(rounder).to be_valid
    end

    it 'flags a decisive team mismatch only under the :team_check context' do
      rounder = Rounder.create!(round: round, steamid: 'STEAM_0:1:1', team: Rounder::TEAM_MARINES)
      create_alien_log_lines('STEAM_0:1:1')

      expect(rounder.valid?(:team_check)).to be false
      expect(rounder.errors[:team].first).to include('stored as marine but round log lines show alien (10/10 events)')
    end

    it 'does not flag a rounder whose team matches the log lines' do
      rounder = Rounder.create!(round: round, steamid: 'STEAM_0:1:1', team: Rounder::TEAM_ALIENS)
      create_alien_log_lines('STEAM_0:1:1')

      expect(rounder.valid?(:team_check)).to be true
    end

    it 'stays quiet below the minimum sample size' do
      rounder = Rounder.create!(round: round, steamid: 'STEAM_0:1:1', team: Rounder::TEAM_MARINES)
      create_alien_log_lines('STEAM_0:1:1', count: 2)

      expect(rounder.valid?(:team_check)).to be true
    end

    it 'stays quiet when the split is not decisive (below MIN_AGREEMENT)' do
      rounder = Rounder.create!(round: round, steamid: 'STEAM_0:1:1', team: Rounder::TEAM_MARINES)
      create_alien_log_lines('STEAM_0:1:1', count: 3)
      2.times do |i|
        LogLine.create!(round: round, event_type: 'role_change', param1: 'soldier', actor_steamid: 'STEAM_0:1:1',
                        raw_text: player_raw('MarineOne', 'STEAM_0:1:1', 'marine1team'),
                        created_at: round.start_time + (100 + i).seconds)
      end

      expect(rounder.valid?(:team_check)).to be true
    end

    it 'stays quiet when there is no observed data for this steamid at all' do
      rounder = Rounder.create!(round: round, steamid: 'STEAM_0:1:1', team: Rounder::TEAM_MARINES)

      expect(rounder.valid?(:team_check)).to be true
    end
  end
end
