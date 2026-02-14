require 'rails_helper'

RSpec.describe Article, type: :model do
  let(:category) { create(:category, domain: Category::DOMAIN_NEWS) }
  let(:admin) { create(:user, :admin) }

  describe 'callbacks' do
    it 'parses markdown text into text_parsed before save' do
      article = Article.new(
        user: admin,
        category: category,
        title: 'Markdown article',
        text: '**bold**',
        text_coding: described_class::CODING_MARKDOWN
      )

      article.save!

      expect(article.text_parsed).to include('<strong>bold</strong>')
    end

    it 'parses bbcode text into text_parsed before save' do
      article = Article.new(
        user: admin,
        category: category,
        title: 'BBCode article',
        text: '[b]bold[/b]',
        text_coding: described_class::CODING_BBCODE
      )

      allow(article).to receive(:bbcode_to_html).with(article.text).and_return('<p>bold</p>')

      expect { article.save! }.to change { article.text_parsed }.from(nil).to('<p>bold</p>')
    end
  end
end
