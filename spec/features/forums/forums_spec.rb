# frozen_string_literal: true

require 'rails_helper'

RSpec.feature 'Forums Management', type: :feature, js: true do
  let(:admin) { create(:user, :admin) }
  let!(:forum) { create(:forum) }
  let!(:group1) { create(:group, name: 'Moderators') }
  let!(:group2) { create(:group, name: 'VIP Users') }

  before do
    # Login as admin
    visit root_path
    find_field('login_username').set(admin.username)
    fill_in 'login_password', with: admin.raw_password
    find('#authentication input[name="commit"]').click
    expect(page).to have_content(I18n.t('login_successful'))
  end

  feature 'Editing forums' do
    scenario 'admin can access forum edit page' do
      visit edit_forum_path(forum)

      expect(page).to have_field('forum_title', with: forum.title)
      expect(page).to have_field('forum_description', with: forum.description)
      expect(page).to have_content('Access Rights')
    end

    scenario 'admin can update forum title and description' do
      visit edit_forum_path(forum)

      fill_in 'forum_title', with: 'Updated Forum Title'
      fill_in 'forum_description', with: 'Updated forum description'
      click_button 'Save'

      expect(page).to have_content(I18n.t(:forums_update))
      expect(page).to have_content('Updated Forum Title')
    end
  end

  feature 'Managing forum access rights' do
    scenario 'admin can add group with read access' do
      visit edit_forum_path(forum)

      # Find the "Grant Access" section
      within('.add-acl') do
        select group1.name, from: 'forumer_group_id'
        select 'Read', from: 'forumer_access'
        click_button 'Add'
      end

      expect(page).to have_content(I18n.t(:groups_added))

      # Verify the group appears in the access list
      within('#acl') do
        expect(page).to have_content(group1.name)
        expect(page).to have_select('forumer_access', selected: 'Read')
      end
    end

    scenario 'admin can add group with reply access' do
      visit edit_forum_path(forum)

      within('.add-acl') do
        select group1.name, from: 'forumer_group_id'
        select 'Reply', from: 'forumer_access'
        click_button 'Add'
      end

      expect(page).to have_content(I18n.t(:groups_added))

      within('#acl') do
        expect(page).to have_content(group1.name)
        expect(page).to have_select('forumer_access', selected: 'Reply')
      end
    end

    scenario 'admin can add group with topic posting access' do
      visit edit_forum_path(forum)

      within('.add-acl') do
        select group1.name, from: 'forumer_group_id'
        select 'Post a Topic', from: 'forumer_access'
        click_button 'Add'
      end

      expect(page).to have_content(I18n.t(:groups_added))

      within('#acl') do
        expect(page).to have_content(group1.name)
        expect(page).to have_select('forumer_access', selected: 'Post a Topic')
      end
    end

    scenario 'admin can update existing group access level' do
      # Create a forumer with read access
      forumer = create(:forumer, forum: forum, group: group1, access: Forumer::ACCESS_READ)

      visit edit_forum_path(forum)

      # Find the row for this group and update its access using XPath
      within(:xpath, "//table[@id='acl']//tr[td[contains(., '#{group1.name}')]]") do
        select 'Reply', from: 'forumer_access'
        click_link 'Update'
      end

      expect(page).to have_content(I18n.t(:groups_acl_update))

      # Verify the access was updated
      forumer.reload
      expect(forumer.access).to eq(Forumer::ACCESS_REPLY)
    end

    scenario 'admin can remove group access' do
      # Create a forumer
      forumer = create(:forumer, forum: forum, group: group1, access: Forumer::ACCESS_READ)

      visit edit_forum_path(forum)

      # Verify the group is present in the access list
      within('#acl') do
        expect(page).to have_content(group1.name)
      end

      # Remove the group using XPath
      within(:xpath, "//table[@id='acl']//tr[td[contains(., '#{group1.name}')]]") do
        click_link 'Remove'
      end

      # Wait for page to reload and verify the group is no longer in the ACL table
      within('#acl', wait: 5) do
        expect(page).not_to have_content(group1.name)
      end

      # Verify forumer was deleted
      expect(Forumer.find_by(id: forumer.id)).to be_nil
    end

    scenario 'admin can add multiple groups with different access levels' do
      visit edit_forum_path(forum)

      # Add first group with read access
      within('.add-acl') do
        select group1.name, from: 'forumer_group_id'
        select 'Read', from: 'forumer_access'
        click_button 'Add'
      end

      expect(page).to have_content(I18n.t(:groups_added))

      # Add second group with topic access
      within('.add-acl') do
        select group2.name, from: 'forumer_group_id'
        select 'Post a Topic', from: 'forumer_access'
        click_button 'Add'
      end

      expect(page).to have_content(I18n.t(:groups_added))

      # Verify both groups appear in the list
      within('#acl') do
        expect(page).to have_content(group1.name)
        expect(page).to have_content(group2.name)

        # Check we have the right number of rows (header + 2 data rows)
        expect(page).to have_selector('tr', count: 3)
      end
    end

    scenario 'access level dropdown displays all available options' do
      visit edit_forum_path(forum)

      # Check the dropdown in the "Grant Access" form
      within('.add-acl') do
        access_options = find('#forumer_access').all('option').map(&:text)
        expect(access_options).to contain_exactly('Read', 'Reply', 'Post a Topic')
      end
    end

    scenario 'access level dropdown works in edit form after adding group' do
      visit edit_forum_path(forum)

      # Add a group
      within('.add-acl') do
        select group1.name, from: 'forumer_group_id'
        select 'Read', from: 'forumer_access'
        click_button 'Add'
      end

      expect(page).to have_content(I18n.t(:groups_added))

      # Check the dropdown in the edit form for the added group using XPath
      within(:xpath, "//table[@id='acl']//tr[td[contains(., '#{group1.name}')]]") do
        access_options = find('select[name="forumer[access]"]').all('option').map(&:text)
        expect(access_options).to contain_exactly('Read', 'Reply', 'Post a Topic')
        expect(page).to have_select('forumer_access', selected: 'Read')
      end
    end
  end

  feature 'Access level dropdown behavior' do
    let!(:forumer_read) { create(:forumer, forum: forum, group: group1, access: Forumer::ACCESS_READ) }

    scenario 'dropdown is not a multi-select box' do
      visit edit_forum_path(forum)

      within(:xpath, "//table[@id='acl']//tr[td[contains(., '#{group1.name}')]]") do
        select_element = find('select[name="forumer[access]"]')

        # Verify it's not a multi-select (should be "false" or nil, not "true")
        expect(select_element[:multiple]).to be_in([nil, false, 'false'])

        # Verify it doesn't have a large size attribute (size > 1 would make it a listbox)
        # size of 0, 1, or nil is fine for a normal dropdown
        size_attr = select_element[:size]
        expect(size_attr.to_i).to be_in([0, 1]) if size_attr
      end
    end

    scenario 'dropdown shows currently selected access level' do
      visit edit_forum_path(forum)

      within(:xpath, "//table[@id='acl']//tr[td[contains(., '#{group1.name}')]]") do
        expect(page).to have_select('forumer_access', selected: 'Read')
      end
    end

    scenario 'can change dropdown selection' do
      visit edit_forum_path(forum)

      within(:xpath, "//table[@id='acl']//tr[td[contains(., '#{group1.name}')]]") do
        # Change from Read to Reply
        select 'Reply', from: 'forumer_access'

        # Verify the selection changed
        expect(page).to have_select('forumer_access', selected: 'Reply')

        # Change to Post a Topic
        select 'Post a Topic', from: 'forumer_access'

        # Verify the selection changed again
        expect(page).to have_select('forumer_access', selected: 'Post a Topic')
      end
    end
  end
end
