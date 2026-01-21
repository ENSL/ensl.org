require 'rails_helper'

RSpec.describe Challenge, type: :model do
  describe 'defaults and status transitions' do
    let(:contest) { create(:contest, default_time: Time.now.utc.change(hour: 15, min: 0)) }
    let(:user1) { create(:user_with_team) }
    let(:team1) { user1.team }
    let(:user2) { create(:user_with_team) }
    let(:team2) { user2.team }
    let(:cont1) { create(:contester, team: team1, contest: contest) }
    let(:cont2) { create(:contester, team: team2, contest: contest) }

    it 'sets defaults on create' do
      mt = 3.days.from_now.change(hour: 18)
      ch = Challenge.create!(contester1: cont1, contester2: cont2, match_time: mt)
      expect(ch.status).to eq(Challenge::STATUS_PENDING)
      expect(ch.default_time).not_to be_nil
      expect(ch.default_time.hour).to eq(contest.default_time.hour)
    end

    it 'generates a match when accepted' do
      ch = Challenge.create!(contester1: cont1, contester2: cont2, match_time: 2.days.from_now)
      expect(Match.where(challenge: ch)).to be_empty
      ch.update!(status: Challenge::STATUS_ACCEPTED)
      m = Match.find_by(challenge: ch)
      expect(m).not_to be_nil
      expect(m.contester1).to eq(cont1)
      expect(m.contester2).to eq(cont2)
    end

    it 'uses default_time for DEFAULT status' do
      ch = Challenge.create!(contester1: cont1, contester2: cont2, match_time: 2.days.from_now)
      ch.update!(status: Challenge::STATUS_DEFAULT)
      m = Match.find_by(challenge: ch)
      expect(m.match_time.to_i).to eq(ch.default_time.to_i)
    end

    it 'creates a forfeit match with scores' do
      ch = Challenge.create!(contester1: cont1, contester2: cont2, match_time: 2.days.from_now)
      ch.update!(status: Challenge::STATUS_FORFEIT)
      m = Match.find_by(challenge: ch)
      expect(m.forfeit).to be true
      expect(m.score1).to eq(4)
      expect(m.score2).to eq(0)
    end
  end

  describe 'permission helpers' do
    let(:contest) { create(:contest, default_time: Time.now.utc) }
    let(:user1) { create(:user_with_team) }
    let(:team1) { user1.team }
    let(:user2) { create(:user_with_team) }
    let(:team2) { user2.team }
    let(:cont1) { create(:contester, team: team1, contest: contest) }
    let(:cont2) { create(:contester, team: team2, contest: contest) }

    it 'allows leader of contester1 to create' do
      ch = Challenge.new(contester1: cont1, contester2: cont2, match_time: 1.day.from_now)
      expect(ch.can_create?(user1)).to be true
    end

    it 'allows leader of contester2 to update when pending' do
      ch = Challenge.create!(contester1: cont1, contester2: cont2, match_time: 1.day.from_now)
      expect(ch.status).to eq(Challenge::STATUS_PENDING)
      expect(ch.can_update?(user2)).to be true
    end

    it 'allows leader of contester1 to destroy when pending' do
      ch = Challenge.create!(contester1: cont1, contester2: cont2, match_time: 1.day.from_now)
      expect(ch.can_destroy?(user1)).to be true
    end
  end
end
