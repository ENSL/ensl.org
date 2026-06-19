# frozen_string_literal: true

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

    it 'leaves text_parsed unchanged when text is nil' do
      post = Post.new(user: user, topic: topic, text: nil)

      expect { post.parse_text }.not_to change(post, :text_parsed)
    end

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

  describe '#number' do
    let(:topic) { create(:topic) }
    let(:post) { build(:post, topic: topic, user: user) }
    let(:pages) { double(per_page: 30, current_page: 3) }

    it 'calculates the row number for paginated pages' do
      expect(post.number(pages, 2)).to eq(63)
    end

    it 'returns the next post number when index is -1' do
      create_list(:post, 2, topic: topic)

      expect(post.number(pages, -1)).to eq(topic.posts.count + 1)
    end
  end

  describe 'permissions' do
    let(:topic) { create(:topic) }
    let(:post) { build(:post, topic: topic, user: user) }

    describe '#can_create?' do
      it 'returns false when current user is missing' do
        expect(post.can_create?(nil)).to be false
      end

      it 'adds an error when the topic is locked' do
        Lock.create!(lockable: topic)

        expect(post.can_create?(user)).to be false
        expect(post.errors[:lock]).to be_present
      end

      it 'adds an error when the user is muted' do
        create(:ban, :mute, user: user)

        expect(post.can_create?(user)).to be false
        expect(post.errors[:user]).to be_present
      end

      it 'adds an error when the user is not verified' do
        allow(user).to receive(:verified?).and_return(false)

        expect(post.can_create?(user)).to be false
        expect(post.errors[:user]).to be_present
      end

      it 'returns true when the user has reply access and no posting errors' do
        expect(post.can_create?(user)).to be true
      end
    end

    describe '#can_update?' do
      it 'returns false when current user is missing' do
        expect(post.can_update?(nil, text: 'updated')).to be false
      end

      it 'allows the post owner with expected params' do
        expect(post.can_update?(user, text: 'updated', topic_id: topic.id)).to be true
      end

      it 'rejects unexpected params for non-admins' do
        expect(post.can_update?(user, text: 'updated', admin: true)).to be_nil
      end

      it 'allows admins regardless of ownership' do
        admin = create(:user, :admin)

        expect(post.can_update?(admin, admin: true)).to be true
      end
    end

    describe '#can_destroy?' do
      it 'returns true only for admins' do
        admin = create(:user, :admin)

        expect(post.can_destroy?(admin)).to be true
        expect(post.can_destroy?(user)).to be false
        expect(post.can_destroy?(nil)).to be_falsey
      end
    end
  end
end
