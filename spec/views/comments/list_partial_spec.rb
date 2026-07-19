# frozen_string_literal: true

require 'rails_helper'

# Regression safety net for app/views/comments/_list.html.erb
# (rendered by CommentsController#show for the AJAX "load older comments" list)
RSpec.describe 'comments/_list', type: :view do
  let(:article) { create(:article) }
  let(:user) { create(:user) }

  it 'renders each comment author and body text, most recent first' do
    older = create(:comment, user: user, commentable: article, text: 'Older comment body', created_at: 2.days.ago)
    newer = create(:comment, user: user, commentable: article, text: 'Newer comment body', created_at: 1.hour.ago)

    render partial: 'comments/list', locals: { comments: [older, newer] }

    expect(rendered).to include(user.username)
    expect(rendered).to include('Older comment body')
    expect(rendered).to include('Newer comment body')
    expect(rendered.index('Newer comment body')).to be < rendered.index('Older comment body')
  end
end
