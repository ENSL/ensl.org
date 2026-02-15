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

  describe 'XSS protection' do
    context 'with BBCode format' do
      it 'strips script tags from text' do
        article = Article.new(
          user: admin,
          category: category,
          title: 'BBCode XSS test',
          text: '[b]bold[/b]<script>alert("xss")</script>',
          text_coding: described_class::CODING_BBCODE
        )

        article.save!

        expect(article.text_parsed).not_to include('<script>')
        expect(article.text_parsed).not_to include('alert')
        expect(article.text_parsed).to include('<strong>bold</strong>')
      end

      it 'strips iframe tags from text' do
        article = Article.new(
          user: admin,
          category: category,
          title: 'BBCode iframe test',
          text: '[b]text[/b]<iframe src="evil.com"></iframe>',
          text_coding: described_class::CODING_BBCODE
        )

        article.save!

        expect(article.text_parsed).not_to include('<iframe')
      end

      it 'strips event handlers from text' do
        article = Article.new(
          user: admin,
          category: category,
          title: 'BBCode event handler test',
          text: '[b]text[/b]<img src=x onerror="alert(1)">',
          text_coding: described_class::CODING_BBCODE
        )

        article.save!

        expect(article.text_parsed).not_to include('onerror')
        expect(article.text_parsed).not_to include('<img')
      end
    end

    context 'with Markdown format' do
      it 'escapes raw HTML script tags' do
        article = Article.new(
          user: admin,
          category: category,
          title: 'Markdown XSS test',
          text: '**bold** <script>alert("xss")</script>',
          text_coding: described_class::CODING_MARKDOWN
        )

        article.save!

        expect(article.text_parsed).not_to include('<script>alert')
        expect(article.text_parsed).to include('<strong>bold</strong>')
        # CommonMarker should omit or comment out raw HTML
        expect(article.text_parsed).to match(/raw HTML omitted|&lt;script&gt;/)
      end

      it 'escapes iframe tags in markdown' do
        article = Article.new(
          user: admin,
          category: category,
          title: 'Markdown iframe test',
          text: '**text** <iframe src="evil.com"></iframe>',
          text_coding: described_class::CODING_MARKDOWN
        )

        article.save!

        expect(article.text_parsed).not_to include('<iframe src=')
      end

      it 'escapes event handlers in markdown' do
        article = Article.new(
          user: admin,
          category: category,
          title: 'Markdown event handler test',
          text: '**text** <img src=x onerror="alert(1)">',
          text_coding: described_class::CODING_MARKDOWN
        )

        article.save!

        expect(article.text_parsed).not_to include('onerror="alert')
      end
    end

    context 'with HTML format' do
      it 'preserves HTML for admin users' do
        article = Article.new(
          user: admin,
          category: category,
          title: 'HTML test',
          text: '<strong>bold</strong>',
          text_coding: described_class::CODING_HTML
        )

        article.save!

        # CODING_HTML doesn't parse, text_parsed should be nil or same as text
        expect(article.text).to eq('<strong>bold</strong>')
      end

      it 'does not process HTML content (stored as-is)' do
        article = Article.new(
          user: admin,
          category: category,
          title: 'HTML raw test',
          text: '<p>Test content</p>',
          text_coding: described_class::CODING_HTML
        )

        article.save!

        # HTML is stored as-is, sanitization happens in views
        expect(article.text).to eq('<p>Test content</p>')
      end
    end
  end
end
