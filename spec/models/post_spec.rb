# == Schema Information
#
# Table name: posts
#
#  id          :integer          not null, primary key
#  text        :text
#  topic_id    :integer
#  user_id     :integer
#  created_at  :datetime
#  updated_at  :datetime
#  text_parsed :text
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
