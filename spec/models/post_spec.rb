# == Schema Information
#
# Table name: posts
#
#  id          :integer          not null, primary key
#  text        :text(65535)
#  text_parsed :text(65535)
#  created_at  :datetime
#  updated_at  :datetime
#  topic_id    :integer
#  user_id     :integer
#
# Indexes
#
#  index_posts_on_topic_id  (topic_id)
#  index_posts_on_user_id   (user_id)
#

require "rails_helper"

describe Post do
  let!(:user) { create :user }

  describe "create" do
    let(:post) { build :post }

    it "creates a new post" do
      # expect(post.valid?).to eq(true)
      post.topic = create :topic
      expect do
        post.save!
      end.to change(Post, :count).by(1)
    end
  end
end
