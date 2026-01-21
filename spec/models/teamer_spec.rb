require 'rails_helper'

RSpec.describe Teamer, type: :model do
  describe 'basic helpers' do
    it 'init_variables sets joiner rank by default' do
      t = Teamer.new
      t.init_variables
      expect(t.rank).to eq Teamer::RANK_JOINER
    end

    it 'to_s delegates to user' do
      t = build(:teamer)
      expect(t.to_s).to eq t.user.to_s
    end
  end

  describe 'validation' do
    it 'does not allow same user to join same team twice' do
      user = create(:user)
      team = create(:team)
      create(:teamer, user: user, team: team)
      t2 = Teamer.new(user: user, team: team)
      t2.validate
      expect(t2.errors[:team]).not_to be_empty
    end
  end

  describe 'destroy behavior' do
    it 'destroys when rank is joiner' do
      t = create(:teamer, rank: Teamer::RANK_JOINER)
      id = t.id
      t.destroy
      expect(Teamer.exists?(id)).to be false
    end

    it 'marks removed when rank is not joiner' do
      t = create(:teamer, rank: Teamer::RANK_MEMBER)
      t.destroy
      expect(t.reload.rank).to eq Teamer::RANK_REMOVED
    end
  end

  describe 'permissions' do
    let(:team) { create(:team) }
    let(:user) { create(:user) }

    it 'can_create? requires verification params' do
      t = Teamer.new(user: user, team: team)
      allow(Verification).to receive(:contain).and_return(true)
      expect(t.can_create?(user, user_id: user.id, team_id: team.id)).to be true
    end

    it 'can_update? requires admin' do
      t = build(:teamer)
      admin = double('User')
      allow(admin).to receive(:admin?).and_return(true)
      expect(t.can_update?(admin)).to be true
    end

    it 'can_destroy? allows owner, leader, or admin' do
      team = create(:team)
      owner = create(:user)
      t = create(:teamer, user: owner, team: team)

      expect(t.can_destroy?(owner)).to be true

      leader = create(:user)
      allow(team).to receive(:is_leader?).with(leader).and_return(true)
      expect(t.can_destroy?(leader)).to be true

      admin = double('User')
      allow(admin).to receive(:admin?).and_return(true)
      allow(team).to receive(:is_leader?).with(admin).and_return(false)
      expect(t.can_destroy?(admin)).to be true

      other = create(:user)
      allow(team).to receive(:is_leader?).with(other).and_return(false)
      allow(other).to receive(:admin?).and_return(false)
      expect(t.can_destroy?(other)).to be false
    end
  end
end
