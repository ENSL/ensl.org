require 'rails_helper'

RSpec.describe Group, type: :model do
  let(:user) { create(:user) }

  describe 'validations' do
    it 'is valid with a short name' do
      g = Group.new(name: 'Short', founder: user)
      expect(g).to be_valid
    end

    it 'validates maximum name length' do
      g = Group.new(name: 'a' * 21)
      expect(g).not_to be_valid
      expect(g.errors[:name]).to be_present
    end
  end

  describe 'associations' do
    it 'has many groupers and users through groupers' do
      g = create(:group)
      u = create(:user)
      create(:grouper, group: g, user: u)

      expect(g.groupers).not_to be_empty
      expect(g.users).to include u
    end
  end

  describe '#to_s' do
    it 'returns the group name' do
      g = Group.new(name: 'TeamX')
      expect(g.to_s).to eq 'TeamX'
    end
  end

  describe 'protected groups and permissions' do
    it 'returns defined constant ids in protected_groups' do
      pg = Group.protected_groups
      expect(pg).to include(Group::ADMINS)
      expect(pg).to include(Group::CASTERS)
    end

    it 'prevents destroying the admins group' do
      admin_group = create(:group, :admin)
      admin_user = double('admin_user')
      allow(admin_user).to receive(:admin?).and_return(true)

      expect(admin_group.can_destroy?(admin_user)).to be false
    end

    it 'allows destroying a regular group for an admin' do
      regular = create(:group)
      admin_user = double('admin_user')
      allow(admin_user).to receive(:admin?).and_return(true)

      expect(regular.can_destroy?(admin_user)).to be true
    end
  end

  describe 'class helpers (admins, staff)' do
    it 'returns admin groupers via .admins' do
      admin_group = create(:group, :admin)
      u = create(:user)
      gpr = create(:grouper, group: admin_group, user: u)

      expect(Group.admins.map(&:user)).to include u
    end

    it 'aggregates staff from various groups' do
      admin_group = create(:group, :admin)
      caster_group = create(:group, :caster)
      ref_group = create(:group, :ref)

      u1 = create(:user)
      u2 = create(:user)
      u3 = create(:user)

      create(:grouper, group: admin_group, user: u1)
      create(:grouper, group: caster_group, user: u2)
      create(:grouper, group: ref_group, user: u3)

      staff_users = Group.staff.map(&:user)
      expect(staff_users).to include(u1, u2, u3)
    end
  end

  describe '.params' do
    it 'permits the name attribute' do
      params = ActionController::Parameters.new(group: { name: 'A' })
      permitted = Group.params(params, nil)
      expect(permitted[:name]).to eq 'A'
    end
  end
end
