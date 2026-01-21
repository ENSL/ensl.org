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

  describe 'match helpers and logic' do
    it 'returns correct score colors for friendly team' do
      contest = create(:contest)
      team1 = create(:team)
      team2 = create(:team)
      cont1 = create(:contester, contest: contest, team: team1)
      cont2 = create(:contester, contest: contest, team: team2)
      match = build(:match, contest: contest, contester1: cont1, contester2: cont2,
                            score1: nil, score2: nil)

      match.friendly = team1
      expect(match.score_color).to eq('black')

      match.score1 = 2
      match.score2 = 2
      expect(match.score_color).to eq('yellow')

      match.score1 = 3
      match.score2 = 1
      expect(match.score_color).to eq('green')

      match.score1 = 1
      match.score2 = 3
      expect(match.score_color).to eq('red')

      match.friendly = team2
      expect(match.score_color).to eq('green')
    end

    it 'returns friendly and opponent details' do
      contest = create(:contest)
      team1 = create(:team)
      team2 = create(:team)
      cont1 = create(:contester, contest: contest, team: team1)
      cont2 = create(:contester, contest: contest, team: team2)
      match = create(:match, contest: contest, contester1: cont1, contester2: cont2,
                             score1: 4, score2: 1, points1: 2, points2: 0)

      match.friendly = team1
      expect(match.get_friendly).to eq(cont1)
      expect(match.get_opponent).to eq(cont2)
      expect(match.get_friendly(:score)).to eq(4)
      expect(match.get_opponent(:score)).to eq(1)
      expect(match.get_friendly(:points)).to eq(2)
      expect(match.get_opponent(:points)).to eq(0)
    end

    it 'returns the opposing team' do
      contest = create(:contest)
      team1 = create(:team)
      team2 = create(:team)
      cont1 = create(:contester, contest: contest, team: team1)
      cont2 = create(:contester, contest: contest, team: team2)
      match = create(:match, contest: contest, contester1: cont1, contester2: cont2)

      expect(match.get_opposing_team(team1)).to eq(team2)
      expect(match.get_opposing_team(team2)).to eq(team1)
    end

    it 'sets motm by username' do
      user = create(:user)
      match = create(:match)

      match.motm_name = user.username
      match.set_motm

      expect(match.motm).to eq(user)
    end
  end
end
