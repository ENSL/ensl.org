# frozen_string_literal: true

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

    it 'normalizes matcher attributes in-place' do
      replacement_user = create(:user)
      match_params = ActionController::Parameters.new(
        matchers_attributes: {
          '0' => { 'user_id' => '', '_destroy' => 'keep' },
          '1' => { 'user_id' => replacement_user.username, '_destroy' => 'keep' },
          '2' => { 'user_id' => 'missing_user', '_destroy' => 'delete' }
        }
      )

      Match.normalize_matchers_attributes!(match_params)

      expect(match_params[:matchers_attributes]).not_to have_key('0')
      expect(match_params[:matchers_attributes]['1']['user_id']).to eq(replacement_user.id)
      expect(match_params[:matchers_attributes]['1']['_destroy']).to be false
      expect(match_params[:matchers_attributes]['2']['user_id']).to eq('missing_user')
      expect(match_params[:matchers_attributes]['2']['_destroy']).to be true
    end
  end

  describe 'set_hltv guard' do
    it 'does not raise when match_time is nil' do
      m = build(:match, match_time: nil)
      expect { m.set_hltv }.not_to raise_error
    end
  end

  describe 'match helpers and logic' do
    it 'formats the match name with both contesters' do
      match = create(:match)
      expect(match.to_s).to eq("#{match.contester1} vs #{match.contester2}")
    end

    it 'returns prediction percentages and rejects invalid contester values' do
      match = create(:match)
      create_list(:prediction, 2, match: match, score1: 3, score2: 1)
      create(:prediction, match: match, score1: 1, score2: 3)

      expect(match.preds(1)).to eq(67)
      expect(match.preds(2)).to eq(33)
      expect { match.preds(3) }.to raise_error(ArgumentError, 'invalid contester')
    end

    it 'returns zero prediction percentage when there are no matching predictions' do
      match = create(:match)
      create(:prediction, match: match, score1: 1, score2: 1)

      expect(match.preds(1)).to eq(0)
    end

    it 'filters mercs and lineups by contester' do
      match = create(:match)
      user1 = create(:user)
      user2 = create(:user)
      merc = Matcher.create!(match: match, user: user1, contester: match.contester1, merc: true)
      starter = Matcher.create!(match: match, user: user2, contester: match.contester2, merc: false)

      expect(match.mercs(match.contester1)).to contain_exactly(merc)
      expect(match.team1_lineup).to contain_exactly(merc)
      expect(match.team2_lineup).to contain_exactly(starter)
    end

    it 'allows the same user on both sides of a match' do
      match = create(:match)
      user = create(:user)

      left = Matcher.create!(match: match, user: user, contester: match.contester1, merc: false)
      right = Matcher.create!(match: match, user: user, contester: match.contester2, merc: true)

      expect(match.team1_lineup).to include(left)
      expect(match.team2_lineup).to include(right)
    end

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

      match.score1 = 4
      match.score2 = 1
      expect(match.score_color).to eq('red')
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

      match.friendly = team2
      expect(match.get_friendly).to eq(cont2)
      expect(match.get_opponent).to eq(cont1)
      expect(match.get_friendly(:score)).to eq(1)
      expect(match.get_opponent(:score)).to eq(4)
      expect(match.get_friendly(:points)).to eq(0)
      expect(match.get_opponent(:points)).to eq(2)
    end

    it 'builds a sanitized demo file name' do
      match = create(:match)
      allow(Verification).to receive(:uncrap).and_return('safe-demo-name')

      expect(match.demo_name).to eq('safe-demo-name')
      expect(Verification).to have_received(:uncrap).with(include(match.id.to_s))
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

    it 'adds an error when both contesters belong to the same team' do
      contest = create(:contest)
      team = create(:team)
      cont1 = create(:contester, contest: contest, team: team)
      cont2 = build(:contester, contest: contest, team: team)
      match = build(:match, contest: contest, contester1: cont1, contester2: cont2)

      match.validate_different_teams

      expect(match.errors[:base]).to include('Contesters must be from different teams.')
    end

    it 'updates prediction results when scores change' do
      match = create(:match)
      hit = create(:prediction, match: match, score1: 4, score2: 2)
      miss = create(:prediction, match: match, score1: 1, score2: 0)

      match.update!(score1: 4, score2: 2)

      expect(hit.reload.result).to eq(1)
      expect(miss.reload.result).to eq(0)
    end
  end

  describe 'authorization helpers' do
    let(:match) { create(:match, match_time: Time.current - 1.hour, score1: nil, score2: nil, forfeit: false) }

    it 'allows admins to update and destroy' do
      admin = instance_double(User, admin?: true)

      expect(match.can_update?(admin)).to be true
      expect(match.can_destroy?(admin)).to be true
    end

    it 'denies updates for nil users' do
      expect(match.can_update?(nil, {})).to be false
    end

    it 'allows the assigned referee to update result fields and hltv requests' do
      referee = create(:user)
      allow(referee).to receive_messages(admin?: false, ref?: true, caster?: false)
      match.referee = referee
      allow(Verification).to receive(:contain).and_return(false)
      allow(Verification).to receive(:contain).with(hash_including(:score1),
                                                    %i[score1 score2 forfeit report demo_id motm_name
                                                       matchers_attributes server_id]).and_return(true)
      allow(Verification).to receive(:contain).with(hash_including(:hltv), [:hltv]).and_return(true)

      expect(match.can_update?(referee, { score1: 4 })).to be true
      expect(match.can_update?(referee, { hltv: true })).to be true
    end

    it 'allows leaders to submit scores after the match and set the stream on match day' do
      leader = create(:user)
      allow(match.contester1.team).to receive(:is_leader?).with(leader).and_return(true)
      allow(match.contester2.team).to receive(:is_leader?).with(leader).and_return(false)
      allow(Verification).to receive(:contain).and_return(false)
      allow(Verification).to receive(:contain).with({ score1: 4, score2: 2 }, %i[score1 score2]).and_return(true)
      allow(Verification).to receive(:contain).with({ stream_id: 7 }, [:stream_id]).and_return(true)

      expect(match.can_update?(leader, { score1: 4, score2: 2 })).to be true

      match.match_time = Time.current
      expect(match.can_update?(leader, { stream_id: 7 })).to be true
    end

    it 'allows a caster to claim and release the caster slot' do
      caster = create(:user)
      allow(caster).to receive_messages(admin?: false, ref?: false, caster?: true)
      allow(Verification).to receive(:contain).and_return(false)
      allow(Verification).to receive(:contain).with({ caster_id: caster.id.to_s }, [:caster_id]).and_return(true)
      allow(Verification).to receive(:contain).with({ caster_id: '' }, [:caster_id]).and_return(true)

      expect(match.can_update?(caster, { caster_id: caster.id.to_s })).to be true

      match.caster_id = caster.id
      expect(match.can_update?(caster, { caster_id: '' })).to be true
    end

    it 'answers proposal and membership helpers' do
      leader = create(:user)
      outsider = create(:user)
      allow(match.contester1.team).to receive(:is_leader?).and_return(false)
      allow(match.contester2.team).to receive(:is_leader?).and_return(false)
      allow(match.contester1.team).to receive(:is_leader?).with(leader).and_return(true)
      allow(match.contester2.team).to receive(:is_leader?).with(leader).and_return(false)
      allow(leader).to receive(:team).and_return(match.contester1.team)

      expect(match.can_make_proposal?(leader)).to be true
      expect(match.can_make_proposal?(outsider)).to be false
      expect(match.user_in_match?(leader)).to be true
      expect(match.user_in_match?(outsider)).to be false
    end

    it 'returns false for can_make_proposal? when user is nil' do
      expect(match.can_make_proposal?(nil)).to be false
    end
  end

  describe 'hltv controls' do
    let(:match) { build(:match, match_time: Time.now.utc) }

    it 'raises when requesting record too far from match time' do
      match.match_time = Time.now.utc + (Match::MATCH_LENGTH * 11)

      expect { match.hltv_record('addr', 'pwd') }
        .to raise_error(Match::Error, I18n.t('hltv_request_20'))
    end

    it 'raises when hltv server is already recording' do
      hltv = instance_double(Server, recording: true, addr: 'hltv.example')
      allow(match).to receive(:hltv).and_return(hltv)

      expect { match.hltv_record('addr', 'pwd') }
        .to raise_error(Match::Error, "#{I18n.t(:hltv_already)}hltv.example")
    end

    it 'raises when no hltv server is available' do
      allow(match).to receive(:hltv).and_return(nil)
      allow(match).to receive(:ensure_hltv).and_return(nil)

      expect { match.hltv_record('addr', 'pwd') }
        .to raise_error(Match::Error, I18n.t(:hltv_notavailable))
    end

    it 'stores reservation details when recording is possible' do
      hltv = instance_double(Server, recording: nil)
      allow(match).to receive(:hltv).and_return(hltv)
      allow(match).to receive(:ensure_hltv).and_return(hltv)
      allow(match).to receive(:save!).and_return(true)
      allow(hltv).to receive(:reservation=).with('addr')
      allow(hltv).to receive(:pwd=).with('pwd')
      allow(hltv).to receive(:recordable=).with(match)
      allow(hltv).to receive(:save!).and_return(true)

      match.hltv_record('addr', 'pwd')

      expect(hltv).to have_received(:reservation=).with('addr')
      expect(hltv).to have_received(:pwd=).with('pwd')
      expect(hltv).to have_received(:recordable=).with(match)
      expect(hltv).to have_received(:save!)
    end

    it 'raises when moving without active hltv recording' do
      allow(match).to receive(:hltv).and_return(nil)

      expect { match.hltv_move('addr', 'pwd') }
        .to raise_error(Match::Error, I18n.t(:hltv_notset))
    end

    it 'moves and stops active hltv reservations' do
      hltv = instance_double(Server, recording: true, reservation: 'current-reservation')
      allow(match).to receive(:hltv).and_return(hltv)
      allow(Server).to receive(:move)
      allow(Server).to receive(:stop)

      match.hltv_move('new-address', 'secret')
      match.hltv_stop

      expect(Server).to have_received(:move).with('current-reservation', 'new-address', 'secret')
      expect(Server).to have_received(:stop).with('current-reservation')
    end
  end

  describe '#confirmed_proposal?' do
    let(:match) { create(:match) }

    it 'is true when a confirmed proposal exists for the match' do
      create(:match_proposal, :confirmed, match: match)
      expect(match.confirmed_proposal?).to be true
    end

    it 'is false when only non-confirmed proposals exist' do
      create(:match_proposal, :pending, match: match)
      expect(match.confirmed_proposal?).to be false
    end

    it 'is false when the match has no proposals' do
      expect(match.confirmed_proposal?).to be false
    end
  end

  describe 'score bookkeeping branches' do
    let(:contest) { instance_double(Contest, contest_type: Contest::TYPE_LEAGUE) }
    let(:team1) { instance_double(Team) }
    let(:team2) { instance_double(Team) }
    let(:contester1) { instance_double(Contester, team: team1, active: true) }
    let(:contester2) { instance_double(Contester, team: team2, active: true) }
    let(:match) { build(:match) }

    before do
      allow(match).to receive(:contest).and_return(contest)
      allow(match).to receive(:contester1).and_return(contester1)
      allow(match).to receive(:contester2).and_return(contester2)

      allow(contester1).to receive_messages(draw: 2, win: 3, loss: 4, score: 10, trend: nil)
      allow(contester2).to receive_messages(draw: 5, win: 6, loss: 7, score: 11, trend: nil)

      allow(contester1).to receive(:draw=)
      allow(contester2).to receive(:draw=)
      allow(contester1).to receive(:win=)
      allow(contester2).to receive(:win=)
      allow(contester1).to receive(:loss=)
      allow(contester2).to receive(:loss=)
      allow(contester1).to receive(:score=)
      allow(contester2).to receive(:score=)
      allow(contester1).to receive(:trend=)
      allow(contester2).to receive(:trend=)
      allow(contester1).to receive(:save!).and_return(true)
      allow(contester2).to receive(:save!).and_return(true)
    end

    it 'recalculate updates draw counts and trends on draw' do
      match.score1 = 2
      match.score2 = 2

      match.recalculate

      expect(contester1).to have_received(:draw=).with(3)
      expect(contester2).to have_received(:draw=).with(6)
      expect(contester1).to have_received(:trend=).with(Contester::TREND_FLAT)
      expect(contester2).to have_received(:trend=).with(Contester::TREND_FLAT)
    end

    it 'recalculate updates win and loss counts when contester1 wins' do
      match.score1 = 4
      match.score2 = 1

      match.recalculate

      expect(contester1).to have_received(:win=).with(4)
      expect(contester2).to have_received(:loss=).with(8)
      expect(contester1).to have_received(:trend=).with(Contester::TREND_UP)
      expect(contester2).to have_received(:trend=).with(Contester::TREND_DOWN)
    end

    it 'recalculate updates win and loss counts when contester2 wins' do
      match.score1 = 1
      match.score2 = 3

      match.recalculate

      expect(contester1).to have_received(:loss=).with(5)
      expect(contester2).to have_received(:win=).with(7)
      expect(contester1).to have_received(:trend=).with(Contester::TREND_DOWN)
      expect(contester2).to have_received(:trend=).with(Contester::TREND_UP)
    end

    it 'reset_contest decrements draw records when prior score was draw' do
      allow(match).to receive(:score1_was).and_return(2)
      allow(match).to receive(:score2_was).and_return(2)

      match.reset_contest

      expect(contester1).to have_received(:draw=).with(1)
      expect(contester2).to have_received(:draw=).with(4)
    end

    it 'reset_contest decrements win and loss records when prior score favored contester1' do
      allow(match).to receive(:score1_was).and_return(3)
      allow(match).to receive(:score2_was).and_return(1)

      match.reset_contest

      expect(contester1).to have_received(:win=).with(2)
      expect(contester2).to have_received(:loss=).with(6)
    end

    it 'reset_contest decrements win and loss records when prior score favored contester2' do
      allow(match).to receive(:score1_was).and_return(1)
      allow(match).to receive(:score2_was).and_return(3)

      match.reset_contest

      expect(contester1).to have_received(:loss=).with(3)
      expect(contester2).to have_received(:win=).with(5)
    end
  end
end
