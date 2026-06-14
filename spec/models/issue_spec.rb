# == Schema Information
#
# Table name: issues
#
#  id          :integer          not null, primary key
#  solution    :text(65535)
#  status      :integer
#  text        :text(65535)
#  text_parsed :text(65535)
#  title       :string(255)
#  created_at  :datetime
#  updated_at  :datetime
#  assigned_id :integer
#  author_id   :integer
#  category_id :integer
#
# Indexes
#
#  index_issues_on_assigned_id  (assigned_id)
#  index_issues_on_author_id    (author_id)
#  index_issues_on_category_id  (category_id)
#

require 'rails_helper'

describe Issue do
  describe 'Permissions' do
    let!(:user) { create :user }
    let!(:admin) { create :user, :admin }
    let(:issue) { Issue.new }

    describe 'can_show?' do
      it 'returns false when current user is nil' do
        expect(issue.can_show?(nil)).to be false
      end

      it 'returns true for author' do
        issue.author = user
        expect(issue.can_show?(user)).to be_truthy
      end

      it 'returns true for admin' do
        expect(issue.can_show?(admin)).to be_truthy
      end

      it 'returns false if neither admin nor author' do
        expect(issue.can_show?(user)).to be_falsey
      end

      it 'returns true for gather moderators assigned to allowed categories' do
        moderator = create(:user)
        create(:grouper, user: moderator, group: create(:group, :gather_moderator))
        issue.category_id = Issue::CATEGORY_GATHER

        expect(issue.can_show?(moderator)).to be_truthy
      end
    end

    describe 'can_create?' do
      it 'returns true' do
        expect(issue.can_create?(nil)).to be_truthy
      end
    end

    describe 'can_update?' do
      it 'returns false when current user is nil' do
        expect(issue.can_update?(nil)).to be false
      end

      it 'returns true for admin' do
        expect(issue.can_update?(admin)).to be_truthy
      end

      it 'returns false for non-admin' do
        expect(issue.can_update?(user)).to be_falsey
      end

      it 'allows gather moderators to update gather issues without changing category' do
        moderator = create(:user)
        create(:grouper, user: moderator, group: create(:group, :gather_moderator))
        issue.category_id = Issue::CATEGORY_GATHER

        expect(issue.can_update?(moderator, category_id: Issue::CATEGORY_GATHER.to_s)).to be_truthy
      end

      it 'rejects category changes from non-admins' do
        moderator = create(:user)
        create(:grouper, user: moderator, group: create(:group, :gather_moderator))
        issue.category_id = Issue::CATEGORY_GATHER

        expect(issue.can_update?(moderator, category_id: Issue::CATEGORY_WEBSITE.to_s)).to be_falsey
      end
    end

    describe 'can_destroy?' do
      it 'returns true for admin' do
        expect(issue.can_destroy?(admin)).to be_truthy
      end

      it 'returns false for non-admin' do
        expect(issue.can_destroy?(user)).to be_falsey
      end
    end
  end

  describe '.allowed_categories' do
    it 'returns only gather for gather moderators' do
      moderator = create(:user)
      create(:grouper, user: moderator, group: create(:group, :gather_moderator))

      expect(described_class.allowed_categories(moderator)).to eq([Issue::CATEGORY_GATHER])
    end

    it 'returns all moderated categories for admins' do
      admin = create(:user, :admin)

      expect(described_class.allowed_categories(admin)).to contain_exactly(
        Issue::CATEGORY_GATHER,
        Issue::CATEGORY_WEBSITE,
        Issue::CATEGORY_LEAGUE,
        Issue::CATEGORY_NSLPLUGIN
      )
    end
  end

  describe 'status helpers' do
    it 'maps statuses to colors' do
      expect(build(:issue, status: Issue::STATUS_OPEN).color).to eq('yellow')
      expect(build(:issue, status: Issue::STATUS_SOLVED).color).to eq('green')
      expect(build(:issue, status: Issue::STATUS_REJECTED).color).to eq('red')
    end

    it 'returns nil for unknown statuses' do
      expect(build(:issue, status: 99).color).to be_nil
    end

    it 'adds an error for invalid statuses' do
      issue = build(:issue, status: 99)

      expect(issue).not_to be_valid
      expect(issue.errors[:status]).to be_present
    end

    it 'accepts valid statuses' do
      issue = build(:issue, status: Issue::STATUS_OPEN)

      issue.valid?

      expect(issue.errors[:status]).to be_empty
    end
  end

  describe 'initialization and parsing helpers' do
    it 'assigns the user from assigned_name and defaults status when missing' do
      assignee = create(:user)
      issue = build(:issue, assigned: nil, assigned_name: assignee.username, status: nil)

      issue.valid?

      expect(issue.assigned).to eq(assignee)
      expect(issue.status).to eq(Issue::STATUS_OPEN)
    end

    it 'leaves text_parsed unchanged when text is nil' do
      issue = build(:issue, text: nil)

      expect { issue.parse_text }.not_to change(issue, :text_parsed)
    end
  end
end
