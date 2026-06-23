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
  end
end
