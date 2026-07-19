# frozen_string_literal: true

require 'rails_helper'

RSpec.describe PostsHelper, type: :helper do
  describe '#post_primary_group_entry' do
    it 'returns nil for nil user' do
      expect(helper.post_primary_group_entry(nil)).to be_nil
    end

    it 'returns nil when the user has no groups' do
      user = create(:user)

      expect(helper.post_primary_group_entry(user)).to be_nil
    end

    it 'prefers admin group entry over other memberships' do
      user = create(:user)
      staff_group = create(:group, id: Group::STAFF, name: 'Staff', founder: user)
      admin_group = create(:group, id: Group::ADMINS, name: 'Admins', founder: user)

      create(:grouper, user: user, group: staff_group, task: 'Staff duties')
      create(:grouper, user: user, group: admin_group, task: 'Admin duties')

      group, task = helper.post_primary_group_entry(user)

      expect(group).to eq(admin_group)
      expect(task).to eq('Admin duties')
    end

    it 'falls back to first grouper for regular users' do
      user = create(:user)
      first_group = create(:group, name: 'Contributors', founder: user)
      second_group = create(:group, name: 'Events', founder: user)

      first = create(:grouper, user: user, group: first_group, task: 'Contributor')
      create(:grouper, user: user, group: second_group, task: 'Coordinator')

      group, task = helper.post_primary_group_entry(user)

      expect(group).to eq(first.group)
      expect(task).to eq(first.task)
    end

    it 'prefers staff group entry for staff users' do
      user = create(:user)
      allow(user).to receive(:staff?).and_return(true)
      allow(user).to receive(:admin?).and_return(false)
      staff_group = create(:group, id: Group::STAFF, name: 'Staff', founder: user)
      fallback_group = create(:group, name: 'Other', founder: user)
      create(:grouper, user: user, group: fallback_group, task: 'Other task')
      create(:grouper, user: user, group: staff_group, task: 'Staff task')

      group, task = helper.post_primary_group_entry(user)

      expect(group).to eq(staff_group)
      expect(task).to eq('Staff task')
    end

    it 'prefers caster group entry for caster users' do
      user = create(:user)
      allow(user).to receive_messages(admin?: false, staff?: false, caster?: true)
      caster_group = create(:group, id: Group::CASTERS, name: 'Casters', founder: user)
      create(:grouper, user: user, group: caster_group, task: 'Caster task')

      group, task = helper.post_primary_group_entry(user)

      expect(group).to eq(caster_group)
      expect(task).to eq('Caster task')
    end

    it 'prefers referee group entry for referee users' do
      user = create(:user)
      allow(user).to receive_messages(admin?: false, staff?: false, caster?: false, ref?: true)
      refs_group = create(:group, id: Group::REFEREES, name: 'Referees', founder: user)
      create(:grouper, user: user, group: refs_group, task: 'Ref task')

      group, task = helper.post_primary_group_entry(user)

      expect(group).to eq(refs_group)
      expect(task).to eq('Ref task')
    end

    it 'returns nil when no target group id can be resolved from first grouper' do
      groupers = instance_double('Groupers')
      user = instance_double(User, groupers: groupers, admin?: false, staff?: false, caster?: false, ref?: false)
      allow(groupers).to receive(:exists?).and_return(true)
      allow(groupers).to receive(:first).and_return(nil)

      expect(helper.post_primary_group_entry(user)).to be_nil
    end

    it 'returns nil when the target group record does not exist' do
      user = create(:user)
      ghost_group = create(:group, name: 'Ghost', founder: user)
      grouper = create(:grouper, user: user, group: ghost_group, task: 'Ghost task')
      ghost_group.destroy!

      result = helper.post_primary_group_entry(user)

      expect(result).to be_nil
      expect(grouper).to be_present
    end
  end
end
