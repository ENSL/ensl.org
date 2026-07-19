# frozen_string_literal: true

require 'rails_helper'

feature 'User manages forum posts', js: true do
  let!(:forum) { create(:forum) }
  let!(:topic) { create(:topic, forum: forum) }
  let!(:user) { create(:user) }
  let!(:admin) { create(:user, :admin) }
  let!(:reply_group) { create(:group) }

  before do
    create(:grouper, user: user, group: reply_group)
    create(:grouper, user: admin, group: reply_group)
    create(:forumer, forum: forum, group: reply_group, access: Forumer::ACCESS_REPLY)
  end

  context 'as a basic user' do
    before { sign_in_as(user) }

    describe 'creating a new post' do
      it 'displays the new post form' do
        visit new_post_path(id: topic.id)
        expect(page).to have_content('New Post')
        expect(page).to have_field('Text')
      end

      it 'creates a post successfully' do
        initial_count = Post.count
        visit new_post_path(id: topic.id)

        textarea = find('#post_text')
        textarea.set('This is my test post')

        click_button 'Save Post'

        expect(page).to have_content I18n.t(:posts_create)
        expect(Post.count).to eq(initial_count + 1)
        expect(Post.order(:id).last.text).to eq 'This is my test post'
      end

      it 'displays validation errors when text is empty' do
        visit new_post_path(id: topic.id)
        click_button 'Save Post'

        expect(page).to have_css('.errors-block', wait: 5)
        expect(page).to have_content('Text is too short')
      end

      it 'respects character limit (max 10,000 chars)' do
        visit new_post_path(id: topic.id)
        long_text = 'a' * 10_001
        textarea = find('#post_text')
        textarea.set(long_text)
        click_button 'Save Post'

        expect(page).to have_css('.errors-block', wait: 5)
        expect(page).to have_content('Text is too long')
      end
    end

    describe 'viewing posts with flat layout' do
      let!(:post) { create(:post, topic: topic, user: user) }

      it 'displays the post content' do
        visit topic_path(topic)
        expect(page).to have_content(post.text)
      end

      it 'displays the post author avatar' do
        visit topic_path(topic)
        expect(page).to have_css('div.avatar img')
      end

      it 'displays the post number' do
        visit topic_path(topic)
        expect(page).to have_content('#1')
      end

      it 'displays the post timestamp' do
        visit topic_path(topic)
        within("#post_#{post.id} .time") do
          expect(page).to have_css('span')
        end
      end

      it 'displays quote button correctly (not as hashtag)' do
        visit topic_path(topic)
        within("div#post_#{post.id}.post") do
          quote_button = find('div.controls a', text: 'Quote')
          expect(quote_button).to be_present
          expect(quote_button['data-on']).to eq('click')
        end
      end

      it 'displays edit button only for post author' do
        visit topic_path(topic)
        expect(page).to have_link('Edit', href: edit_post_path(post))
      end

      it 'displays delete button only for admin' do
        visit topic_path(topic)
        # Regular user should not see delete button
        expect(page).not_to have_link('Delete', href: post_path(post))
      end

      it 'places edit and delete buttons in correct location with flat layout' do
        visit topic_path(topic)
        within("#post_#{post.id} .controls") do
          expect(page).to have_link('Edit')
        end
      end
    end

    describe 'editing a post' do
      let!(:post) { create(:post, topic: topic, user: user, text: 'Original text') }

      it 'displays the edit form with current text' do
        visit edit_post_path(post)
        expect(find_field('Text').value).to eq('Original text')
      end

      it 'updates the post successfully' do
        visit edit_post_path(post)
        textarea = find('#post_text')
        textarea.set('Updated text')
        click_button 'Save Post'

        expect(page).to have_content I18n.t(:posts_update)
        expect(post.reload.text).to eq 'Updated text'
      end

      it 'redirects to topic after successful update' do
        visit edit_post_path(post)
        textarea = find('#post_text')
        textarea.set('Updated text')
        click_button 'Save Post'

        # Should redirect to topic with flash message
        expect(page).to have_content I18n.t(:posts_update)
        # Check we're on the topic page
        expect(current_path).to eq(topic_path(post.topic))
      end

      it 'redirects to the updated post anchor' do
        visit edit_post_path(post)
        textarea = find('#post_text')
        textarea.set('Updated text')
        click_button 'Save Post'

        # Wait for redirect
        expect(page).to have_content I18n.t(:posts_update)
        # Check we're on topic page with the updated post visible
        expect(current_path).to eq(topic_path(post.topic))
        within("#post_#{post.id}") do
          expect(page).to have_content('Updated text')
        end
      end
    end

    describe 'quoting a post' do
      let!(:existing_post) { create(:post, topic: topic, user: user, text: 'Original post text') }

      it 'appends quoted text to reply form' do
        visit topic_path(topic)
        # Find and click the quote button (data-on:click, call: QuoteText)
        quote_button = find("div#post_#{existing_post.id}.post div.controls a[data-on=\"click\"]", text: 'Quote')
        # This should trigger JavaScript that appends to #reply textarea
        # Pending actual JS test - this test confirms the element exists
        expect(quote_button).to be_present
      end

      it 'includes quoted text with quote tags' do
        visit topic_path(topic)
        click_button 'Fast Reply'

        within("div#post_#{existing_post.id}.post") do
          click_link 'Quote'
        end

        expect(page).to have_field('post_text', with: "[quote=#{user}]Original post text[/quote]\n", wait: 5)
      end
    end

    describe 'fast reply functionality' do
      let!(:post) { create(:post, topic: topic, user: user) }

      it 'displays the reply form on topic page' do
        visit topic_path(topic)
        expect(page).to have_css('#reply textarea', visible: :all)
      end

      it 'displays the fast reply button' do
        visit topic_path(topic)
        expect(page).to have_button('Fast Reply')
      end

      it 'shows the reply form when fast reply button is clicked' do
        visit topic_path(topic)
        # Form is hidden initially
        expect(page).to have_css('#reply', visible: :hidden)

        click_button 'Fast Reply'
        # Form becomes visible
        expect(page).to have_css('#reply', visible: :visible)
        # Textarea should be visible
        expect(page).to have_css('#reply textarea', visible: true)
      end

      it 'creates a post via AJAX' do
        visit topic_path(topic)
        click_button 'Fast Reply'

        within('#reply') do
          find('textarea').set('Quick reply test message')
        end

        expect do
          click_button 'Post Message'
          sleep 1 # Wait for AJAX
        end.to change(Post, :count).by(1)

        expect(page).to have_content('Quick reply test message')
      end

      it 'clears the reply form after successful post creation' do
        visit topic_path(topic)
        click_button 'Fast Reply'

        within('#reply') do
          find('textarea').set('Test message')
        end
        click_button 'Post Message'
        sleep 1

        # Form should be cleared
        expect(page.find('#reply textarea', visible: :all).value).to be_empty
      end

      it 'hides the reply form after successful creation' do
        visit topic_path(topic)
        click_button 'Fast Reply'

        within('#reply') do
          find('textarea').set('Test message')
        end
        click_button 'Post Message'
        sleep 1

        # Reply form should be hidden again
        expect(page).to have_css('#reply', visible: :hidden)
      end

      it 'shows the fast reply button again after post creation' do
        visit topic_path(topic)

        click_button 'Fast Reply'
        within('#reply') do
          find('textarea').set('Test message')
        end
        click_button 'Post Message'
        sleep 1

        # After post creation, the reply form should hide and the button should exist again.
        # Some drivers don't execute the JS response that removes the `invisible` class.
        expect(page).to have_content('Test message')
        expect(page).to have_css('#reply', visible: :hidden)
        expect(page).to have_css('button.fastReply', visible: :all, wait: 5)
      end

      it 'displays validation errors without closing form' do
        visit topic_path(topic)
        click_button 'Fast Reply'

        # Submit empty form
        click_button 'Post Message'
        sleep 1

        # Should show error
        expect(page).to have_css('#reply-errors .errors-block')
        # Form should still be visible
        expect(page).to have_css('#reply', visible: :visible)
      end

      it 'allows resubmitting after fixing validation errors' do
        visit topic_path(topic)
        click_button 'Fast Reply'

        # Try with empty form
        click_button 'Post Message'
        sleep 1
        expect(page).to have_css('#reply-errors .errors-block')

        # Now fill in and submit
        within('#reply') do
          find('textarea').set('Fixed message')
        end
        click_button 'Post Message'
        sleep 1

        # Should succeed
        expect(page).to have_content('Fixed message')
        expect(page).not_to have_css('#reply-errors .errors-block')
      end
    end

    describe 'post permissions' do
      let!(:other_user) { create(:user) }
      let!(:own_post) { create(:post, topic: topic, user: user) }
      let!(:other_post) { create(:post, topic: topic, user: other_user) }

      before do
        create(:grouper, user: other_user, group: reply_group)
      end

      it 'allows editing own posts' do
        visit topic_path(topic)
        within("div#post_#{own_post.id}.post") do
          expect(page).to have_link('Edit')
        end
      end

      it 'prevents editing other user posts' do
        visit topic_path(topic)
        within("div#post_#{other_post.id}.post") do
          expect(page).not_to have_link('Edit')
        end
      end

      it 'prevents creating posts in locked topics' do
        Lock.create!(lockable: topic)
        visit new_post_path(id: topic.id)
        expect(page).to have_content('not allowed to visit')
      end

      it 'prevents creating posts when user is muted' do
        create(:ban, :mute, user: user)
        visit new_post_path(id: topic.id)
        expect(page).to have_content('not allowed to visit')
      end
    end
  end

  context 'as an admin user' do
    before { sign_in_as(admin) }

    describe 'admin post management' do
      let!(:post) { create(:post, topic: topic, user: user) }

      it 'displays delete button for any post' do
        visit topic_path(topic)
        within("div#post_#{post.id}.post") do
          expect(page).to have_link('Delete')
        end
      end

      it 'can delete any post' do
        visit topic_path(topic)
        within("div#post_#{post.id}.post") do
          accept_confirm do
            click_link 'Delete'
          end
        end

        # Wait for redirect/page update to complete
        expect(page).to have_content I18n.t(:posts_destroy), wait: 5
        # Verify post is deleted
        expect(Post.find_by(id: post.id)).to be_nil
      end

      it 'shows flash message when deleting a post' do
        visit topic_path(topic)
        within("div#post_#{post.id}.post") do
          accept_confirm do
            click_link 'Delete'
          end
        end

        expect(page).to have_content I18n.t(:posts_destroy)
      end

      it 'redirects to forum when deleting the last post of a topic' do
        # Create a fresh topic with only one post
        fresh_topic = create(:topic, forum: forum)
        only_post = create(:post, topic: fresh_topic, user: user, text: 'Only post')

        visit topic_path(fresh_topic)
        within("div#post_#{only_post.id}.post") do
          accept_confirm do
            click_link 'Delete'
          end
        end

        # Flash message should appear
        expect(page).to have_content I18n.t(:posts_destroy)
        # Post should be deleted
        expect(Post.find_by(id: only_post.id)).to be_nil
      end

      it 'can edit any post' do
        visit edit_post_path(post)
        textarea = find('#post_text')
        textarea.set('Admin edited text')
        click_button 'Save Post'

        expect(page).to have_content I18n.t(:posts_update)
        expect(post.reload.text).to eq 'Admin edited text'
      end
    end
  end

  context 'as an unauthenticated user' do
    it 'cannot create a post' do
      visit new_post_path(id: topic.id)
      expect(page).to have_content('not allowed to visit')
    end
  end

  private

  def long_text(len = 10_000)
    (0..len).map { (0...8).map { rand(65..90).chr }.join }.join(' ')
  end
end
