# frozen_string_literal: true

# == Schema Information
#
# Table name: topics
#
#  id         :integer          not null, primary key
#  state      :integer          default(0), not null
#  title      :string(255)
#  created_at :datetime
#  updated_at :datetime
#  forum_id   :integer
#  user_id    :integer
#
# Indexes
#
#  index_topics_on_forum_id  (forum_id)
#  index_topics_on_user_id   (user_id)
#

require 'rails_helper'

describe Topic do
  let!(:user) { create :user }
  let!(:forum) { create :forum }

  describe 'create' do
    let(:topic) { build :topic, user: user, forum: forum }

    it 'creates a new topic' do
      topic.first_post = 'Foo'
      expect do
        topic.save!
      end.to change(Topic, :count).by(1)
    end
  end

  describe '.recent_topics' do
    it 'returns 5 unique, most recently posted topics' do
      10.times do
        create :topic, first_post: 'Foo'
      end

      recent_topics = Topic.recent_topics

      post_max_ids = Post.group(:topic_id).maximum(:id)
      top_200 = post_max_ids.sort_by { |_topic_id, max_id| -max_id }.first(200)

      expected_ids = []
      top_200.each do |topic_id, _max_id|
        topic = Topic.find_by(id: topic_id)
        next unless topic
        next if Forumer.exists?(forum_id: topic.forum_id)

        expected_ids << topic_id
        break if expected_ids.length == 5
      end

      expect(recent_topics.map(&:id)).to eq(expected_ids)
      expect(recent_topics.map(&:id).uniq.length).to eq(5)
    end

    it 'does not return posts from restricted forums' do
      restricted_topic = create :topic, title: 'Restricted'
      create :forumer, forum: restricted_topic.forum
      create :post, topic: restricted_topic
      expect(Topic.recent_topics).to_not include(restricted_topic)
    end
  end

  describe '#can_show?' do
    it 'allows public forum for anonymous user' do
      topic = create(:topic, user: user, forum: forum)
      expect(topic.can_show?(nil)).to be true
    end

    it 'blocks restricted forum for anonymous user' do
      restricted_topic = create(:topic, user: user, forum: forum)
      create(:forumer, forum: restricted_topic.forum, access: Forumer::ACCESS_READ)
      expect(restricted_topic.can_show?(nil)).to be false
    end

    it 'allows restricted forum for group member' do
      restricted_topic = create(:topic, user: user, forum: forum)
      group = create(:group)
      create(:forumer, forum: restricted_topic.forum, group: group, access: Forumer::ACCESS_READ)
      create(:grouper, user: user, group: group)

      expect(restricted_topic.can_show?(user)).to be_truthy
    end

    it 'returns nil when forum is missing instead of raising' do
      topic = create(:topic, user: user, forum: forum)
      topic.update_column(:forum_id, nil)

      expect { topic.can_show?(nil) }.not_to raise_error
      expect(topic.can_show?(nil)).to be_nil
    end
  end

  describe '#can_create?' do
    it 'returns false for anonymous user' do
      topic = build(:topic, user: user, forum: forum)
      expect(topic.can_create?(nil)).to be false
    end

    it 'returns false for muted users' do
      topic = build(:topic, user: user, forum: forum)
      create(:ban, :mute, user: user)
      expect(topic.can_create?(user)).to be false
      expect(topic.errors[:bans]).not_to be_empty
    end

    it 'returns true when user is allowed and not muted' do
      topic = build(:topic, user: user, forum: forum)
      expect(topic.can_create?(user)).to be true
    end

    it 'returns false for users who are not yet verified' do
      topic = build(:topic, user: user, forum: forum)
      allow(user).to receive(:verified?).and_return(false)

      expect(topic.can_create?(user)).to be false
      expect(topic.errors[:bans]).not_to be_empty
    end
  end

  describe '#can_update? and #can_destroy?' do
    it 'allows admin' do
      admin = create(:user, :admin)
      topic = create(:topic, user: admin, forum: forum)

      expect(topic.can_update?(admin)).to be true
      expect(topic.can_destroy?(admin)).to be true
    end

    it 'blocks non-admin' do
      topic = create(:topic, user: user, forum: forum)
      expect(topic.can_update?(user)).to be false
      expect(topic.can_destroy?(user)).to be false
    end
  end

  describe '#last_page and #states' do
    it 'computes last_page based on posts count' do
      topic = create(:topic, user: user, forum: forum, first_post: 'Foo')
      expect(topic.last_page).to eq(1)

      Topic::POSTS_PAGE.times do
        create(:post, topic: topic, user: user)
      end

      expect(topic.last_page).to eq(2)
    end

    it 'returns states mapping' do
      topic = build(:topic, user: user, forum: forum)
      expect(topic.states).to eq({ Topic::STATE_NORMAL => 'Normal', Topic::STATE_STICKY => 'Sticky' })
    end
  end

  describe '#record_view_count and #view_count' do
    it 'records views and counts them' do
      topic = create(:topic, user: user, forum: forum, first_post: 'Foo')
      topic.record_view_count('127.0.0.1', true)
      topic.record_view_count('127.0.0.2', false)

      expect(topic.view_count).to eq(2)
    end
  end
end
