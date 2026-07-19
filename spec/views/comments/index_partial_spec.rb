# frozen_string_literal: true

require 'rails_helper'

# Regression safety net for app/views/comments/_index.html.erb
#
# `comments`/`comment` are required locals (always passed by
# ApplicationHelper#add_comments). A future edit that drops an `<%=` or
# breaks that local wiring would fail silently in the browser - Rails
# raises no error for a stray `<%` - so these specs assert on the actual
# rendered content.
RSpec.describe 'comments/_index', type: :view do
  let(:article) { create(:article) }
  let(:user) { create(:user) }

  before do
    create(:profile, user: user)
    view.define_singleton_method(:cuser) { nil }
  end

  it 'renders the comments heading' do
    render partial: 'comments/index', locals: { comment: Comment.new(commentable: article), comments: [] }

    expect(rendered).to include('Comments')
  end

  it 'renders each comment body and author' do
    comment = create(:comment, user: user, commentable: article, text: 'Locals comment body')

    render partial: 'comments/index', locals: { comment: Comment.new(commentable: article), comments: [comment] }

    expect(rendered).to include(user.username)
    expect(rendered).to include('Locals comment body')
  end

  it 'renders the new comment form so visitors can post a reply' do
    render partial: 'comments/index', locals: { comment: Comment.new(commentable: article), comments: [] }

    expect(rendered).to include('New Comment')
    expect(rendered).to include('Please log in')
  end

  context 'when a user is signed in' do
    it 'renders the comment textarea instead of the login prompt' do
      signed_in_user = user
      view.define_singleton_method(:cuser) { signed_in_user }

      render partial: 'comments/index', locals: { comment: Comment.new(commentable: article), comments: [] }

      expect(rendered).to include('Post Comment')
      expect(rendered).not_to include('Please log in')
    end
  end
end
