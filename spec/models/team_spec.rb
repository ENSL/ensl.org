require 'rails_helper'

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
      team.update_attribute(:active, false)
      team.recover
      expect(team.active).to be true
    end
  end
end
