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

require 'rails_helper'

describe Post do
  let!(:user) { create :user }

  describe 'create' do
    let(:post) { build :post }

    it 'creates a new post' do
      # expect(post.valid?).to eq(true)
      post.topic = create :topic
      expect do
        post.save!
      end.to change(Post, :count).by(1)
    end
  end

  describe 'XSS protection' do
    let(:topic) { create(:topic) }

    it 'strips script tags from BBCode text' do
      post = Post.new(
        user: user,
        topic: topic,
        text: '[b]bold[/b]<script>alert("xss")</script>'
      )

      post.save!

      expect(post.text_parsed).not_to include('<script>')
      expect(post.text_parsed).not_to include('alert')
      expect(post.text_parsed).to include('<strong>bold</strong>')
    end

    it 'strips iframe tags from text' do
      post = Post.new(
        user: user,
        topic: topic,
        text: '[i]text[/i]<iframe src="evil.com"></iframe>'
      )

      post.save!

      expect(post.text_parsed).not_to include('<iframe')
    end

    it 'strips event handlers from text' do
      post = Post.new(
        user: user,
        topic: topic,
        text: '[url]link[/url]<img src=x onerror="alert(1)">'
      )

      post.save!

      expect(post.text_parsed).not_to include('onerror')
      expect(post.text_parsed).not_to include('<img')
    end
  end
end
