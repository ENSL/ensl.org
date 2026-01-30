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
end
