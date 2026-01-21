require 'rails_helper'

RSpec.describe MatchProposal, type: :model do
  describe 'permissions and status transitions' do
    let(:contest) { create(:contest) }
    let(:user1) { create(:user_with_team) }
    let(:team1) { user1.team }
    let(:user2) { create(:user_with_team) }
    let(:team2) { user2.team }
    let(:cont1) { create(:contester, team: team1, contest: contest) }
    let(:cont2) { create(:contester, team: team2, contest: contest) }
    let(:match) { create(:match, contest: contest, contester1: cont1, contester2: cont2) }

    it 'allows team leaders and admins to create proposals' do
      prop = MatchProposal.new(match: match, team: team1, proposed_time: 1.day.from_now)
      expect(prop.can_create?(user1)).to be true
      admin = create(:user, :admin)
      expect(prop.can_create?(admin)).to be true
      expect(prop.can_create?(nil)).to be false
    end

    it 'permits the opposing team to confirm a pending proposal when in time' do
      prop = MatchProposal.create!(match: match, team: team1, proposed_time: 1.hour.from_now, status: MatchProposal::STATUS_PENDING)
      # user2 is leader of the opposing team
      expect(prop.can_update?(user2, status: MatchProposal::STATUS_CONFIRMED)).to be true
    end

    it 'allows proposer to revoke a pending proposal' do
      prop = MatchProposal.create!(match: match, team: team1, proposed_time: 1.day.from_now, status: MatchProposal::STATUS_PENDING)
      expect(prop.can_update?(user1, status: MatchProposal::STATUS_REVOKED)).to be true
    end

    it 'allows admin to delay a confirmed match if within limit and not playing' do
      admin = create(:user, :admin)
      prop = MatchProposal.create!(match: match, team: team1, proposed_time: 10.minutes.from_now, status: MatchProposal::STATUS_CONFIRMED)
      expect(prop.can_update?(admin, status: MatchProposal::STATUS_DELAYED)).to be true
    end

    it 'identifies immutable states' do
      prop = MatchProposal.new(match: match, team: team1, proposed_time: 1.day.from_now)
      prop.status = MatchProposal::STATUS_REJECTED
      expect(prop.state_immutable?).to be true
      prop.status = MatchProposal::STATUS_DELAYED
      expect(prop.state_immutable?).to be true
      prop.status = MatchProposal::STATUS_REVOKED
      expect(prop.state_immutable?).to be true
      prop.status = MatchProposal::STATUS_PENDING
      expect(prop.state_immutable?).to be false
    end

    it 'permits params correctly' do
      params = ActionController::Parameters.new(match_proposal: { status: MatchProposal::STATUS_PENDING,
                                                                  match_id: match.id, team_id: team1.id, proposed_time: Time.now.utc })
      permitted = MatchProposal.params(params, user1)
      expect(permitted[:match_id]).to eq(match.id)
      expect(permitted[:team_id]).to eq(team1.id)
    end

    it 'confirmed_upcoming scope returns confirmed future proposals' do
      prop = MatchProposal.create!(match: match, team: team1, proposed_time: 2.hours.from_now, status: MatchProposal::STATUS_CONFIRMED)
      expect(MatchProposal.confirmed_upcoming).to include(prop)
    end

    it 'can_destroy? requires admin' do
      admin = create(:user, :admin)
      prop = MatchProposal.new(match: match, team: team1, proposed_time: 1.day.from_now)
      expect(prop.can_destroy?(admin)).to be true
      expect(prop.can_destroy?(user1)).to be false
    end
  end
end
