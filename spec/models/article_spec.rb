# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Article, type: :model do
  let(:category) { create(:category, domain: Category::DOMAIN_NEWS) }
  let(:admin) { create(:user, :admin) }
  let(:author) { create(:user) }

  describe '#init_variables' do
    it 'forces draft status and downgrades html coding for non-admin users' do
      article = described_class.new(user: author, status: described_class::STATUS_PUBLISHED,
                                    text_coding: described_class::CODING_HTML)

      article.init_variables

      expect(article.status).to eq(described_class::STATUS_DRAFT)
      expect(article.text_coding).to eq(described_class::CODING_BBCODE)
    end

    it 'leaves admin status and html coding unchanged' do
      article = described_class.new(user: admin, status: described_class::STATUS_PUBLISHED,
                                    text_coding: described_class::CODING_HTML)

      article.init_variables

      expect(article.status).to eq(described_class::STATUS_PUBLISHED)
      expect(article.text_coding).to eq(described_class::CODING_HTML)
    end
  end

  describe '#format_text' do
    it 'leaves parsed text unchanged for html coding' do
      article = described_class.new(text: '<b>safe</b>', text_coding: described_class::CODING_HTML)

      expect { article.format_text }.not_to change(article, :text_parsed)
    end
  end

  describe '#send_notifications' do
    let(:article) do
      described_class.new(user: admin, category: category, title: 'Published article',
                          text: 'body', status: described_class::STATUS_PUBLISHED)
    end

    it 'notifies opted-in news readers' do
      recipient = create(:user)
      profiles = [double(user: recipient), double(user: nil)]

      expect(Profile).to receive(:includes).with(:user).and_return(Profile)
      expect(Profile).to receive(:where).with('notify_news = 1').and_return(profiles)
      expect(Notifications).to receive(:news).with(recipient, article).once

      article.send_notifications
    end

    it 'notifies opted-in article readers' do
      article.category = create(:category, domain: Category::DOMAIN_ARTICLES)
      recipient = create(:user)

      expect(Profile).to receive(:includes).with(:user).and_return(Profile)
      expect(Profile).to receive(:where).with('notify_articles = 1').and_return([double(user: recipient)])
      expect(Notifications).to receive(:article).with(recipient, article).once

      article.send_notifications
    end

    it 'does nothing for unpublished records' do
      article.status = described_class::STATUS_DRAFT

      expect(Profile).not_to receive(:includes)

      article.send_notifications
    end

    it 'does nothing for unsupported category domains' do
      allow(article).to receive(:category).and_return(instance_double(Category, domain: 999))

      expect(Profile).not_to receive(:includes)

      article.send_notifications
    end
  end

  describe 'visibility and permissions' do
    let(:article) do
      create(:article, user: author, category: category, status: described_class::STATUS_DRAFT)
    end

    it 'hides drafts from guests' do
      expect(article.can_show?(nil)).to be_nil
    end

    it 'shows drafts to the author' do
      expect(article.can_show?(author)).to be(true)
    end

    it 'shows drafts to admins' do
      expect(article.can_show?(admin)).to be(true)
    end

    it 'shows published articles to guests' do
      article.update!(status: described_class::STATUS_PUBLISHED)

      expect(article.can_show?(nil)).to be(true)
    end

    it 'blocks creation for banned users and allows non-banned users' do
      banned_user = instance_double(User, banned?: true)
      allowed_user = instance_double(User, banned?: false)

      expect(article.can_create?(nil)).to be_nil
      expect(article.can_create?(banned_user)).to be(false)
      expect(article.can_create?(allowed_user)).to be(true)
    end
  end

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
