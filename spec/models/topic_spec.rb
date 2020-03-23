# == Schema Information
#
# Table name: topics
#
#  id         :integer          not null, primary key
#  state      :integer          default("0"), not null
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

require "rails_helper"

describe Topic do
  let!(:user) { create :user }
  let!(:forum) { create :forum }

  describe "create" do
    let(:topic) { build :topic, user: user, forum: forum }

    it "creates a new topic" do
      topic.first_post = "Foo"
      expect do
        topic.save!
      end.to change(Topic, :count).by(1)
    end
  end

  describe ".recent_topics" do
    # # FIXME: this tests the wrong thing. The model returns by recent 5 posts
    # it "returns 5 unique, most recently posted topics" do
    #   topics = []
    #   10.times do
    #     topic = create :topic, first_post: "Foo"
    #     topics.push(topic)
    #   end
    #   recent_topics = Topic.recent_topics
    #   byebug
    #   topics.last(5).each do |topic|
    #     expect(recent_topics).to include(topic)
    #   end
    # end

    it "does not return posts from restricted forums" do
      restricted_topic = create :topic, title: "Restricted"
      create :forumer, forum: restricted_topic.forum
      create :post, topic: restricted_topic
      expect(Topic.recent_topics).to_not include(restricted_topic)
    end
  end
end
