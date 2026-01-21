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
  end

  describe 'relations and destructive helpers' do
    it 'delegates get_matches to contest.matches.where' do
      contester = create(:contester)
      matches_rel = double('Relation')
      allow(contester.contest).to receive(:matches).and_return(matches_rel)
      expect(matches_rel).to receive(:where).with('contester1_id = ? OR contester2_id = ?', contester.id,
                                                  contester.id).and_return(:found)
      expect(contester.get_matches).to eq :found
    end

    it 'calls update_attribute on destroy' do
      contester = build(:contester)
      expect(contester).to receive(:update_attribute).with(:active, false)
      contester.destroy
    end
  end
end
