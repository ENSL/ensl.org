# == Schema Information
#
# Table name: forums
#
#  id          :integer          not null, primary key
#  description :string(255)
#  position    :integer
#  title       :string(255)
#  created_at  :datetime
#  updated_at  :datetime
#  category_id :integer
#
# Indexes
#
#  index_forums_on_category_id  (category_id)
#

require 'rails_helper'

describe Forum do
  let!(:user) { create :user }
  let(:admin) do
    create(:user).tap do |admin_user|
      create(:grouper, user: admin_user, group: create(:group, :admin))
    end
  end

  describe 'create' do
    let(:forum) { build :forum }

    it 'creates a new forum' do
      expect(forum.valid?).to eq(true)
      expect do
        forum.save!
      end.to change(Forum, :count).by(1)
    end
  end

  describe '.public_forums' do
    it 'returns only forums without read restrictions' do
      public_forum = create(:forum)
      restricted_forum = create(:forum)
      create(:forumer, forum: restricted_forum, group: create(:group), access: Forumer::ACCESS_READ)

      expect(Forum.public_forums).to include(public_forum)
      expect(Forum.public_forums).not_to include(restricted_forum)
    end
  end

  describe '.available_to' do
    it 'returns public forums and forums granted through group membership' do
      member = create(:user)
      group = create(:group)
      public_forum = create(:forum)
      restricted_forum = create(:forum)

      create(:grouper, user: member, group: group)
      create(:forumer, forum: restricted_forum, group: group, access: Forumer::ACCESS_READ)

      forums = Forum.available_to(member, Forumer::ACCESS_READ)

      expect(forums).to include(public_forum)
      expect(forums).to include(restricted_forum)
    end

    it 'returns restricted forums to admins' do
      restricted_forum = create(:forum)
      create(:forumer, forum: restricted_forum, group: create(:group), access: Forumer::ACCESS_READ)

      expect(Forum.available_to(admin, Forumer::ACCESS_READ)).to include(restricted_forum)
    end
  end

  describe '#can_show?' do
    it 'allows anonymous access to public forums' do
      expect(create(:forum).can_show?(nil)).to be true
    end

    it 'blocks anonymous access to restricted forums' do
      forum = create(:forum)
      create(:forumer, forum: forum, group: create(:group), access: Forumer::ACCESS_READ)

      expect(forum.can_show?(nil)).to be false
    end

    it 'allows a member with forum access' do
      member = create(:user)
      group = create(:group)
      forum = create(:forum)

      create(:grouper, user: member, group: group)
      create(:forumer, forum: forum, group: group, access: Forumer::ACCESS_READ)

      expect(forum.can_show?(member)).to be_present
    end
  end

  describe 'management permissions' do
    let(:forum) { build(:forum) }

    it 'allows admins to create, update, and destroy forums' do
      expect(forum.can_create?(admin)).to be true
      expect(forum.can_update?(admin)).to be true
      expect(forum.can_destroy?(admin)).to be true
    end

    it 'blocks non-admin users from managing forums' do
      expect(forum.can_create?(user)).to be false
      expect(forum.can_create?(nil)).to be_falsey
      expect(forum.can_update?(nil)).to be_falsey
      expect(forum.can_destroy?(user)).to be false
      expect(forum.can_destroy?(nil)).to be_falsey
    end
  end
end
