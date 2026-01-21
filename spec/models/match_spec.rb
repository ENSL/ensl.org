require 'rails_helper'

RSpec.describe Match, type: :model do
  describe 'scopes and params' do
    it 'unreffed returns matches without a referee' do
      m1 = create(:match)
      m2 = create(:match)
      m2.update(referee: create(:user))
      expect(Match.unreffed).to include(m1)
      expect(Match.unreffed).not_to include(m2)
    end

    it 'of_team returns matches for a team' do
      team = create(:team)
      contest = create(:contest)
      c1 = create(:contester, team: team, contest: contest)
      other_team = create(:team)
      c2 = create(:contester, team: other_team, contest: contest)
      m = create(:match, contest: contest, contester1: c1, contester2: c2)
      expect(Match.of_team(team)).to include(m)
    end

    it 'params permits server_id' do
      params = ActionController::Parameters.new(match: { server_id: 5 })
      permitted = Match.params(params, nil)
      expect(permitted[:server_id]).to eq 5
    end
  end

  describe 'set_hltv guard' do
    it 'does not raise when match_time is nil' do
      m = build(:match, match_time: nil)
      expect { m.set_hltv }.not_to raise_error
    end
  end
end
