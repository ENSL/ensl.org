# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Contester, type: :model do
  describe 'basic behavior' do
    let(:contester) { create(:contester) }

    it 'initializes variables with init_variables' do
      c = Contester.new
      c.init_variables
      expect(c.active).to be true
      expect(c.trend).to eq Contester::TREND_FLAT
      expect(c.extra).to eq 0
    end

    it 'computes total as score + extra' do
      contester.update(score: 3, extra: 2)
      expect(contester.total).to eq 5
    end

    it 'delegates to_s to team' do
      expect(contester.to_s).to eq contester.team.to_s
    end

    it 'returns statuses mapping' do
      expect(contester.statuses[true]).to eq 'Active'
      expect(contester.statuses[false]).to eq 'Inactive'
    end

    it 'returns the correct lineup relation for open and closed contests' do
      open_relation = double('open_lineup')
      closed_relation = double('closed_lineup')
      allow(contester.team).to receive_message_chain(:teamers, :active).and_return(open_relation)
      allow(contester.team).to receive_message_chain(:teamers, :distinct).and_return(closed_relation)

      allow(contester.contest).to receive(:status).and_return(Contest::STATUS_OPEN)
      expect(contester.lineup).to eq(open_relation)

      allow(contester.contest).to receive(:status).and_return(Contest::STATUS_CLOSED)
      expect(contester.lineup).to eq(closed_relation)
    end

    it 'computes stats from finished matches for either side of the pairing' do
      match_as_contester1 = instance_double(Match, score1: 4, score2: 2, contester1_id: contester.id)
      draw_match = instance_double(Match, score1: 1, score2: 1, contester1_id: contester.id)
      match_as_contester2 = instance_double(Match, score1: 1, score2: 3, contester1_id: contester.id + 100)

      stats = contester.stats_from_matches([match_as_contester1, draw_match, match_as_contester2])

      expect(stats).to eq(win: 2, loss: 0, draw: 1)
    end

    it 'counts losses when the contester loses as either side of the match' do
      loss_as_contester1 = instance_double(Match, score1: 1, score2: 3, contester1_id: contester.id)
      loss_as_contester2 = instance_double(Match, score1: 4, score2: 2, contester1_id: contester.id + 100)

      stats = contester.stats_from_matches([loss_as_contester1, loss_as_contester2])

      expect(stats).to eq(win: 0, loss: 2, draw: 0)
    end
  end

  describe 'validation helpers' do
    it 'adds error when contest already ended' do
      contester = build(:contester)
      past = create(:contest, start: 2.days.ago, 'end' => 1.day.ago, status: Contest::STATUS_OPEN)
      contester.contest = past
      contester.validate_contest
      expect(contester.errors[:base]).to include 'Cannot join contest! It is already over!'
    end

    it 'adds error when signups are closed' do
      contester = build(:contester)
      future = create(:contest, start: 1.day.ago, 'end' => 1.day.from_now, status: Contest::STATUS_PROGRESS)
      contester.contest = future
      contester.validate_contest
      expect(contester.errors[:base]).to include 'Cannot join contest! Signups are closed!'
    end

    it 'requires at least six active players' do
      contester = build(:contester)
      allow(contester.team).to receive_message_chain(:teamers, :active, :unique_by_team, :count).and_return(5)

      contester.validate_playernumber

      expect(contester.errors[:team]).not_to be_empty
    end

    it 'allows teams with at least six active players' do
      contester = build(:contester)
      allow(contester.team).to receive_message_chain(:teamers, :active, :unique_by_team, :count).and_return(6)

      contester.validate_playernumber

      expect(contester.errors[:team]).to be_empty
    end
  end

  describe 'authorization helpers' do
    let(:contester) { create(:contester) }
    let(:team) { contester.team }

    it 'returns false when no user is provided' do
      expect(contester.can_create?(nil)).to be false
    end

    it 'returns false for banned users' do
      user = double('User')
      allow(user).to receive(:banned?).with(Ban::TYPE_LEAGUE).and_return(true)
      expect(contester.can_create?(user)).to be false
    end

    it 'returns true for admin users' do
      user = double('User')
      allow(user).to receive(:banned?).with(Ban::TYPE_LEAGUE).and_return(false)
      allow(user).to receive(:admin?).and_return(true)
      expect(contester.can_create?(user)).to be true
    end

    it 'returns true for team leader with valid params' do
      user = double('User')
      allow(user).to receive(:banned?).with(Ban::TYPE_LEAGUE).and_return(false)
      allow(user).to receive(:admin?).and_return(false)
      allow(team).to receive(:is_leader?).with(user).and_return(true)
      allow(Verification).to receive(:contain).and_return(true)
      expect(contester.can_create?(user, team_id: 1, contest_id: 2)).to be true
    end

    it 'returns false for a leader when params are not allowed' do
      user = double('User')
      allow(user).to receive(:banned?).with(Ban::TYPE_LEAGUE).and_return(false)
      allow(user).to receive(:admin?).and_return(false)
      allow(team).to receive(:is_leader?).with(user).and_return(true)
      allow(Verification).to receive(:contain).and_return(false)

      expect(contester.can_create?(user, invalid: true)).to be false
    end

    it 'can_destroy? true for admin or leader, false otherwise' do
      admin = double('User')
      allow(admin).to receive(:admin?).and_return(true)
      allow(team).to receive(:is_leader?).with(admin).and_return(false)
      expect(contester.can_destroy?(admin)).to be true

      leader = create(:user)
      allow(leader).to receive(:admin?).and_return(false)
      allow(team).to receive(:is_leader?).with(leader).and_return(true)
      expect(contester.can_destroy?(leader)).to be true

      other = create(:user)
      allow(other).to receive(:admin?).and_return(false)
      allow(team).to receive(:is_leader?).with(other).and_return(false)
      expect(contester.can_destroy?(other)).to be false
    end

    it 'returns false from can_destroy? when no user is provided' do
      expect(contester.can_destroy?(nil)).to be false
    end

    it 'returns true from can_update? only for admins' do
      admin = instance_double(User, admin?: true)
      member = instance_double(User, admin?: false)

      expect(contester.can_update?(admin)).to be true
      expect(contester.can_update?(member)).to be false
      expect(contester.can_update?(nil)).to be false
    end
  end

  describe 'relations and destructive helpers' do
    it 'delegates matches_for_contester to contest.matches.where' do
      contester = create(:contester)
      matches_rel = double('Relation')
      allow(contester.contest).to receive(:matches).and_return(matches_rel)
      expect(matches_rel).to receive(:where).with('contester1_id = ? OR contester2_id = ?', contester.id,
                                                  contester.id).and_return(:found)
      expect(contester.matches_for_contester).to eq :found
    end

    it 'calls update! on destroy' do
      contester = build(:contester)
      expect(contester).to receive(:update!).with(active: false)
      contester.destroy
    end

    it 'initializes ladder scores sequentially and preserves explicit scores' do
      ladder = create(:contest, contest_type: Contest::TYPE_LADDER)
      create(:contester, contest: ladder, score: 3)
      create(:contester, contest: ladder, score: 5)

      next_contester = create(:contester, contest: ladder, score: nil)
      preset_contester = create(:contester, contest: ladder, score: 42)

      expect(next_contester.score).to eq(6)
      expect(preset_contester.score).to eq(42)
    end

    it 'permits expected params' do
      params = ActionController::Parameters.new(contester: { team_id: 1, contest_id: 2, ignored: 'x' })

      expect(Contester.params(params, nil).to_h).to eq('team_id' => 1, 'contest_id' => 2)
    end
  end

  describe '.build_for_create' do
    it 'assigns actor and ladder join score for ladder contests' do
      actor = create(:user)
      ladder = create(:contest, contest_type: Contest::TYPE_LADDER)
      create(:contester, contest: ladder)
      team = create(:team)
      raw_params = ActionController::Parameters.new(contester: { team_id: team.id, contest_id: ladder.id })

      contester, contester_params = described_class.build_for_create(raw_params: raw_params, actor: actor)

      expect(contester.user).to eq(actor)
      expect(contester.score).to eq(2)
      expect(contester_params.to_h).to include('team_id' => team.id, 'contest_id' => ladder.id)
    end

    it 'keeps default score for non-ladder contests' do
      actor = create(:user)
      bracket = create(:contest, contest_type: Contest::TYPE_BRACKET)
      team = create(:team)
      raw_params = ActionController::Parameters.new(contester: { team_id: team.id, contest_id: bracket.id })

      contester, = described_class.build_for_create(raw_params: raw_params, actor: actor)

      expect(contester.user).to eq(actor)
      expect(contester.score).to eq(0)
    end
  end

  describe '#rebalance_ladder_rank!' do
    it 'does nothing for non-ladder contests' do
      bracket = create(:contest, contest_type: Contest::TYPE_BRACKET)
      contester = create(:contester, contest: bracket, score: 1)

      expect(bracket).not_to receive(:update_ranks)
      expect { contester.rebalance_ladder_rank!(2) }.not_to raise_error
    end

    it 'raises when requested ladder rank is out of range' do
      ladder = create(:contest, contest_type: Contest::TYPE_LADDER)
      contester = create(:contester, contest: ladder, score: 1)

      expect { contester.rebalance_ladder_rank!(0) }.to raise_error(Exceptions::Error)
      expect { contester.rebalance_ladder_rank!(99) }.to raise_error(Exceptions::Error)
    end

    it 'does not update ranks when the requested rank is unchanged' do
      ladder = create(:contest, contest_type: Contest::TYPE_LADDER)
      contester = create(:contester, contest: ladder, score: 1)
      create(:contester, contest: ladder, score: 2)

      expect(ladder).not_to receive(:update_ranks)
      contester.rebalance_ladder_rank!(1)
    end

    it 'updates ranks when the requested rank changes' do
      ladder = create(:contest, contest_type: Contest::TYPE_LADDER)
      contester = create(:contester, contest: ladder, score: 1)
      create(:contester, contest: ladder, score: 2)

      expect(ladder).to receive(:update_ranks).with(contester, 1, 2)
      contester.rebalance_ladder_rank!(2)
    end
  end
end
