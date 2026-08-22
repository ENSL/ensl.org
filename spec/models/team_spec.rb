# frozen_string_literal: true

# rubocop:disable Rails/SkipsModelValidations
require 'rails_helper'

RSpec.describe Team, type: :model do
  describe 'callbacks and helpers' do
    it 'initializes default attributes on create' do
      team = create(:team)
      expect(team.active).to be true
      expect(team.recruiting).to be_nil
    end

    it 'adds founder as a leader and sets founder.team_id' do
      founder = create(:user)
      team = create(:team, founder: founder)

      leader = team.teamers.find_by(user_id: founder.id)
      expect(leader).not_to be_nil
      expect(leader.rank).to eq(Teamer::RANK_LEADER)
      expect(founder.reload.team_id).to eq(team.id)
    end
  end

  describe '#destroy' do
    context 'when no matches exist' do
      it 'removes the team record and dependent associations' do
        team = create(:team)
        create(:teamer, team: team)
        create(:contester, team: team)

        expect { team.destroy }.to change(Team, :count).by(-1)
        expect(Team.where(id: team.id)).to be_empty
      end
    end

    context 'when matches exist' do
      it 'soft-deletes the team and marks teamers as removed' do
        team = create(:team)
        contest = create(:contest)
        cont1 = create(:contester, contest: contest, team: team)
        cont2 = create(:contester, contest: contest)
        create(:match, contest: contest, contester1: cont1, contester2: cont2)
        create(:teamer, team: team, rank: Teamer::RANK_MEMBER)

        team.destroy

        expect(Team.exists?(team.id)).to be true
        expect(team.reload.active).to be false
        expect(team.teamers.reload.pluck(:rank)).to include(Teamer::RANK_REMOVED)
      end
    end
  end

  describe '#recover' do
    it 'reactivates a soft-deleted team' do
      team = create(:team, active: false)
      team.recover
      expect(team.reload.active).to be true
    end
  end

  describe '#is_leader?' do
    it 'returns true for a leader user' do
      user = create(:user)
      team = create(:team)
      create(:teamer, team: team, user: user, rank: Teamer::RANK_LEADER)

      expect(team.is_leader?(user)).to be true
    end

    it 'returns false for non-leader user' do
      user = create(:user)
      team = create(:team)
      expect(team.is_leader?(user)).to be false
    end
  end

  describe '#apply_member_rank_updates!' do
    it 'promotes joiners and persists comment without running full user validations' do
      leader = create(:user)
      team = create(:team, founder: leader)
      joiner = create(:user, username: 'JoinerOne')
      duplicate = create(:user, username: 'JoinerTwo')
      duplicate.update_column(:username, joiner.username.downcase)
      member = create(:teamer, team: team, user: joiner, rank: Teamer::RANK_JOINER)

      expect { joiner.update!(team_id: team.id) }.to raise_error(ActiveRecord::RecordInvalid)

      expect do
        team.apply_member_rank_updates!(
          actor: leader,
          rank_params: { member.id.to_s => Teamer::RANK_MEMBER.to_s },
          comment_params: { member.id.to_s => 'Good player' }
        )
      end.not_to raise_error

      expect(member.reload.rank).to eq(Teamer::RANK_MEMBER)
      expect(member.comment).to eq('Good player')
      expect(joiner.reload.team_id).to eq(team.id)
    end

    it 'does not assign the primary team when promotion fails' do
      leader = create(:user)
      team = create(:team, founder: leader)
      joiner = create(:user)
      member = create(:teamer, team: team, user: joiner, rank: Teamer::RANK_JOINER)

      team.apply_member_rank_updates!(
        actor: leader,
        rank_params: { member.id.to_s => Teamer::RANK_MEMBER.to_s },
        comment_params: { member.id.to_s => 'longer than fifteen characters' }
      )

      expect(member.reload.rank).to eq(Teamer::RANK_JOINER)
      expect(joiner.reload.team_id).to be_nil
    end
  end

  describe '.search' do
    it 'finds by name case-insensitively' do
      t = create(:team, name: 'Alpha Team')
      expect(Team.search('alpha')).to include(t)
    end

    it 'returns all when search is nil' do
      expect(Team.search(nil)).to match_array(Team.all.to_a)
    end
  end

  describe '.not_in_contest' do
    it 'filters out teams already entered in the contest when given a contest object' do
      contest = create(:contest)
      included_team = create(:team)
      excluded_team = create(:team)
      create(:contester, contest: contest, team: excluded_team)

      teams = Team.not_in_contest(contest)

      expect(teams).to include(included_team)
      expect(teams).not_to include(excluded_team)
    end

    it 'accepts a raw contest id' do
      contest = create(:contest)
      excluded_team = create(:team)
      create(:contester, contest: contest, team: excluded_team)

      expect(Team.not_in_contest(contest.id)).not_to include(excluded_team)
    end
  end

  describe '#init_variables' do
    it 'preserves teamers_count when already set' do
      team = Team.new(teamers_count: 4)

      team.init_variables

      expect(team.teamers_count).to eq(4)
    end
  end

  describe '#add_leader' do
    it 'returns without creating a leader when founder is missing' do
      team = create(:team, founder: nil)

      expect(Teamer.where(team_id: team.id)).to be_empty
    end
  end

  describe '.params' do
    it 'returns an empty hash when params are nil' do
      expect(Team.params(nil, nil)).to eq({})
    end

    it 'returns an empty hash when the team payload is missing' do
      params = ActionController::Parameters.new(other: { name: 'Ignored' })

      expect(Team.params(params, nil)).to eq({})
    end

    it 'permits team params and strips protected attributes' do
      params = ActionController::Parameters.new(
        team: {
          id: 3,
          active: false,
          founder_id: 7,
          name: 'Allowed',
          tag: 'TAG',
          comment: 'Hello',
          teamers_count: 500,
          created_at: Time.current,
          updated_at: Time.current
        }
      )

      permitted = Team.params(params, nil)

      expect(permitted.to_h).to include('name' => 'Allowed', 'tag' => 'TAG', 'comment' => 'Hello')
      expect(permitted.to_h).not_to have_key('id')
      expect(permitted.to_h).not_to have_key('active')
      expect(permitted.to_h).not_to have_key('founder_id')
      expect(permitted.to_h).not_to have_key('teamers_count')
    end
  end
end

RSpec.describe Team, type: :model do
  describe 'init and leader assignment' do
    it 'initializes active and recruiting' do
      t = Team.new
      t.send(:init_variables)
      expect(t.active).to be true
      expect(t.recruiting).to be_nil
    end

    it 'adds founder as leader on create' do
      user = create(:user)
      team = Team.create!(name: 'TeamX', tag: 'TX', founder: user)
      expect(team.leaders.count).to eq(1)
      expect(user.reload.team_id).to eq(team.id)
    end
  end

  describe 'destroy behavior' do
    it 'clears users team_id when permanently deleting a team' do
      team = create(:team)
      user = create(:user)
      create(:teamer, team: team, user: user, rank: Teamer::RANK_MEMBER)
      user.update!(team_id: team.id)

      team.destroy

      expect(user.reload.team_id).to be_nil
    end

    it 'preserves users team_id when archiving a team with matches' do
      team = create(:team)
      user = create(:user)
      create(:teamer, team: team, user: user, rank: Teamer::RANK_MEMBER)
      user.update!(team: team)
      contest = create(:contest)
      contester = create(:contester, team: team, contest: contest)
      create(:match, contest: contest, contester1: contester, contester2: create(:contester, contest: contest))

      team.destroy

      expect(user.reload.team).to eq(team)
      expect(user.active_team).to be_nil
    end

    it 'marks inactive and updates teamers when matches exist' do
      team = create(:team)
      create(:teamer, team: team)
      # create a contester and match to simulate matches.present?
      contest = create(:contest)
      contester = create(:contester, team: team, contest: contest)
      other = create(:contester, contest: contest)
      create(:match, contest: contest, contester1: contester, contester2: other, score1: 1, score2: 0)

      expect(team.matches.count).to be_positive
      team.destroy
      team.reload
      expect(team.active).to be false
      expect(team.teamers.pluck(:rank)).to include(Teamer::RANK_REMOVED)
    end
  end
end
# rubocop:enable Rails/SkipsModelValidations

RSpec.describe Team, type: :model do
  describe 'basic methods' do
    it 'initializes variables with init_variables' do
      t = Team.new
      t.init_variables
      expect(t.active).to be true
      expect(t.recruiting).to be_nil
    end

    it 'search finds by name' do
      t = create(:team, name: 'UniqueSearchName')
      expect(Team.search('UniqueSearchName')).to include t
    end

    it 'to_s returns name' do
      t = build(:team, name: 'MyTeam')
      expect(t.to_s).to eq 'MyTeam'
    end
  end

  describe 'callbacks and leaders' do
    it 'add_leader creates a leader Teamer and sets founder.team_id' do
      user = create(:user)
      team = create(:team, founder: user)
      user.reload
      expect(user.team_id).to eq team.id
      expect(team.leaders.count).to be >= 1
    end

    it 'is_leader? detects team leaders' do
      user = create(:user)
      team = create(:team, founder: user)
      expect(team.is_leader?(user)).to be true
    end
  end

  describe 'permissions' do
    let(:team) { create(:team) }

    it 'can_create? returns false for banned user, true otherwise' do
      user = double('User')
      allow(user).to receive(:banned?).with(Ban::TYPE_MUTE).and_return(true)
      expect(team.can_create?(user)).to be false
      allow(user).to receive(:banned?).with(Ban::TYPE_MUTE).and_return(false)
      expect(team.can_create?(user)).to be true
    end

    it 'can_update? returns true for leader or admin' do
      user = create(:user)
      allow(team).to receive(:is_leader?).with(user).and_return(true)
      expect(team.can_update?(user)).to be true

      admin = double('User')
      allow(admin).to receive(:admin?).and_return(true)
      allow(team).to receive(:is_leader?).with(admin).and_return(false)
      expect(team.can_update?(admin)).to be true
    end

    it 'can_destroy? returns true only for admin' do
      admin = double('User')
      allow(admin).to receive(:admin?).and_return(true)
      expect(team.can_destroy?(admin)).to be true
      other = double('User')
      allow(other).to receive(:admin?).and_return(false)
      expect(team.can_destroy?(other)).to be false
    end
  end

  describe 'destroy/recover behavior' do
    it 'destroy removes team when no matches' do
      team = create(:team)
      id = team.id
      team.destroy
      expect(Team.exists?(id)).to be false
    end

    it 'recover sets active true' do
      team = create(:team)
      team.update!(active: false)
      team.recover
      expect(team.active).to be true
    end
  end
end
