# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Comment, type: :model do
  let(:user) { create(:user) }
  let(:other_user) { create(:user) }
  let(:post_record) { create(:post) }

  describe 'validations' do
    it 'is valid with a user, commentable and text' do
      c = Comment.new(user: user, commentable: post_record, text: 'hello')
      expect(c).to be_valid
    end

    it 'requires a user' do
      c = Comment.new(commentable: post_record, text: 'x')
      expect(c).not_to be_valid
      expect(c.errors[:user]).to be_present
    end

    it 'requires a commentable' do
      c = Comment.new(user: user, text: 'x')
      expect(c).not_to be_valid
      expect(c.errors[:commentable]).to be_present
    end

    it 'validates text length (max 10000)' do
      long = 'a' * 10_001
      c = Comment.new(user: user, commentable: post_record, text: long)
      expect(c).not_to be_valid
      expect(c.errors[:text]).to be_present
    end
  end

  describe 'callbacks' do
    it 'leaves text_parsed unchanged when text is nil' do
      c = Comment.new(user: user, commentable: post_record, text: nil)

      expect { c.parse_text }.not_to change(c, :text_parsed)
    end

    it 'parses text into text_parsed before save' do
      c = Comment.new(user: user, commentable: post_record, text: '[b]bold[/b]')
      allow(c).to receive(:bbcode_to_html).with(c.text).and_return('<p>bold</p>')
      expect { c.save! }.to change { c.text_parsed }.from(nil).to('<p>bold</p>')
    end
  end

  describe 'permissions helpers' do
    describe '#can_create?' do
      it 'returns false when no current user provided' do
        c = Comment.new(user: user, commentable: post_record, text: 'x')
        expect(c.can_create?(nil)).to be false
      end

      it 'returns true for a verified, non-banned user' do
        cuser = double('current_user', banned?: false, verified?: true)
        c = Comment.new(user: user, commentable: post_record, text: 'x')
        expect(c.can_create?(cuser)).to be true
      end

      it 'returns false for unverified user' do
        cuser = double('current_user', banned?: false, verified?: false)
        c = Comment.new(user: user, commentable: post_record, text: 'x')
        expect(c.can_create?(cuser)).to be false
      end
    end

    describe '#can_update?' do
      it 'allows the owner to update' do
        c = Comment.create!(user: user, commentable: post_record, text: 'x')
        expect(c.can_update?(user)).to be true
      end

      it 'allows admins to update' do
        admin = double('admin_user')
        allow(admin).to receive(:admin?).and_return(true)
        c = Comment.create!(user: user, commentable: post_record, text: 'x')
        expect(c.can_update?(admin)).to be true
      end

      it 'denies other non-admin users' do
        c = Comment.create!(user: user, commentable: post_record, text: 'x')
        expect(c.can_update?(other_user)).to be false
      end
    end

    describe '#can_destroy?' do
      it 'allows admins to destroy' do
        admin = double('admin_user')
        allow(admin).to receive(:admin?).and_return(true)
        c = Comment.create!(user: user, commentable: post_record, text: 'x')
        expect(c.can_destroy?(admin)).to be true
      end

      it 'denies non-admins from destroying' do
        c = Comment.create!(user: user, commentable: post_record, text: 'x')
        expect(c.can_destroy?(other_user)).to be false
      end
    end
  end

  describe '.params' do
    it 'permits the expected comment params' do
      params = ActionController::Parameters.new(
        comment: { text: 'x', user_id: 1, commentable_type: 'Post', commentable_id: 2 }
      )
      permitted = Comment.params(params, nil)
      expect(permitted[:text]).to eq 'x'
      expect(permitted[:user_id]).to eq 1
      expect(permitted[:commentable_type]).to eq 'Post'
      expect(permitted[:commentable_id]).to eq 2
    end

    it 'raises when comment key is missing' do
      params = ActionController::Parameters.new({})
      expect { Comment.params(params, nil) }.to raise_error(ActionController::ParameterMissing)
    end
  end

  describe 'XSS protection' do
    it 'strips script tags from BBCode text' do
      comment = Comment.new(
        user: user,
        commentable: post_record,
        text: '[b]bold[/b]<script>alert("xss")</script>'
      )

      comment.save!

      expect(comment.text_parsed).not_to include('<script>')
      expect(comment.text_parsed).not_to include('alert')
      expect(comment.text_parsed).to include('<strong>bold</strong>')
    end

    it 'strips iframe tags from text' do
      comment = Comment.new(
        user: user,
        commentable: post_record,
        text: '[i]text[/i]<iframe src="evil.com"></iframe>'
      )

      comment.save!

      expect(comment.text_parsed).not_to include('<iframe')
    end

    it 'strips event handlers from text' do
      comment = Comment.new(
        user: user,
        commentable: post_record,
        text: '[b]text[/b]<img src=x onerror="alert(1)">'
      )

      comment.save!

      expect(comment.text_parsed).not_to include('onerror')
      expect(comment.text_parsed).not_to include('<img')
    end

    it 'strips style tags with javascript' do
      comment = Comment.new(
        user: user,
        commentable: post_record,
        text: '[b]text[/b]<style>body{background:url("javascript:alert(1)")}</style>'
      )

      comment.save!

      expect(comment.text_parsed).not_to include('<style')
      expect(comment.text_parsed).not_to include('javascript:')
    end
  end
end
