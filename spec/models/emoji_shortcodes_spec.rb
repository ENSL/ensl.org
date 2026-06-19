# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Emoji shortcode parsing' do
  it 'parses shortcodes/emoticons for all main content models', :aggregate_failures do
    user = create(:user)
    other_user = create(:user)
    category = create(:category)
    article = create(:article, user: user, category: category, text: ':smile:', text_coding: Article::CODING_BBCODE)

    post = create(:post, user: user, topic: create(:topic, user: user), text: ':heart:')
    comment = Comment.create!(user: user, commentable: article, text: ':fire:')
    message = create(:message, sender: user, recipient: other_user, text: ':tada:')
    issue = create(:issue, author: user, text: ':rocket:')
    shoutmsg = Shoutmsg.create!(user: user, text: ':)')
    markdown_article = create(:article,
                              user: user,
                              category: category,
                              text: ':smile:',
                              text_coding: Article::CODING_MARKDOWN)

    expect(article.text_parsed).to include('😄')
    expect(post.text_parsed).to include('❤️')
    expect(comment.text_parsed).to include('🔥')
    expect(message.text_parsed).to include('🎉')
    expect(issue.text_parsed).to include('🚀')
    expect(shoutmsg.text).to include('😊')
    expect(markdown_article.text_parsed).to include('😄')
  end
end
