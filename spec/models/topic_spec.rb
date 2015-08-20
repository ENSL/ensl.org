# == Schema Information
#
# Table name: topics
#
#  id         :integer          not null, primary key
#  title      :string(255)
#  user_id    :integer
#  forum_id   :integer
#  created_at :datetime
#  updated_at :datetime
#  state      :integer          default(0), not null
#

require "spec_helper"

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
    before(:all) do
      5.times do
        topic = create :topic
        3.times { create :post, topic: topic }
      end
    end
    it "returns 5 unique, most recently posted topics" do
      recent_topics = Topic.recent_topics
      expect(recent_topics.length).to eq(5)
      expect(recent_topics.map(&:id).uniq.length).to eq(5)
    end
  end
end
