# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Article, type: :model do
  let(:category) { create(:category, domain: Category::DOMAIN_NEWS) }
  let(:admin) { create(:user, :admin) }
  let(:author) { create(:user) }

  describe 'category scopes' do
    it 'filters by domain and excludes the special category' do
      news_category = create(:category, domain: Category::DOMAIN_NEWS)
      article_category = create(:category, domain: Category::DOMAIN_ARTICLES)
      special_category = create(:category, id: Category::SPECIAL, domain: Category::DOMAIN_ARTICLES)
      news = create(:article, category: news_category)
      article = create(:article, category: article_category)
      special = create(:article, category: special_category)

      expect(described_class.domain(Category::DOMAIN_NEWS)).to contain_exactly(news)
      expect(described_class.news).to contain_exactly(news)
      expect(described_class.articles).to contain_exactly(article, special)
      expect(described_class.articles.nospecial).to contain_exactly(article)
    end
  end

  describe '#init_variables' do
    it 'forces draft status and preserves the selected format for non-admin users' do
      article = described_class.new(user: author, status: described_class::STATUS_PUBLISHED,
                                    text_coding: described_class::CODING_HTML)

      article.init_variables

      expect(article.status).to eq(described_class::STATUS_DRAFT)
      expect(article.text_coding).to eq(described_class::CODING_HTML)
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

  describe 'format conversion' do
    it 'converts HTML to Markdown' do
      html = '<h2>Heading</h2><p>A <strong>bold</strong> link to <a href="/rules">rules</a>.</p>'
      article = create(:article, user: admin, category: category, text_coding: described_class::CODING_HTML, text: html)

      article.update!(text_coding: described_class::CODING_MARKDOWN)

      expect(article.text).to include('## Heading', '**bold**', '[rules](/rules)')
      expect(article.text_parsed).to include('<h2', '>Heading<', '<strong>bold</strong>')
    end

    it 'converts BBCode to Markdown' do
      article = legacy_bbcode_article('[b]Bold[/b] and [url=/rules]rules[/url]')

      article.update!(text_coding: described_class::CODING_MARKDOWN)

      expect(article.text).to include('**Bold**', '[rules](/rules)')
    end

    it 'rejects every unsupported conversion' do
      unsupported = [
        [described_class::CODING_HTML, described_class::CODING_BBCODE],
        [described_class::CODING_MARKDOWN, described_class::CODING_HTML],
        [described_class::CODING_MARKDOWN, described_class::CODING_BBCODE],
        [described_class::CODING_BBCODE, described_class::CODING_HTML]
      ]

      unsupported.each do |source, target|
        article = if source == described_class::CODING_BBCODE
                    legacy_bbcode_article('[b]Bold[/b]')
                  else
                    create(:article, user: admin, category: category, text_coding: source, text: 'Bold')
                  end

        expect(article.update(text_coding: target)).to be(false)
        expect(article.errors[:text_coding]).to include('cannot be converted between those formats')
        expect(article.reload.text_coding).to eq(source)
      end
    end

    it 'rejects changing the content and format together' do
      article = create(:article, user: admin, category: category, text_coding: described_class::CODING_HTML,
                                 text: '<p>Original</p>')

      expect(article.update(text: '<p>Changed</p>', text_coding: described_class::CODING_MARKDOWN)).to be(false)
      expect(article.errors[:text_coding]).to include('cannot be changed while editing the content')
      expect(article.reload.text).to eq('<p>Original</p>')
    end

    it 'rejects BBCode for new articles' do
      article = build(:article, user: admin, category: category, text_coding: described_class::CODING_BBCODE)

      expect(article).not_to be_valid
      expect(article.errors[:text_coding]).to include('BBCode is not supported for new articles')
    end
  end

  describe 'read marks' do
    let(:article) { create(:article, user: admin, category: category) }
    let(:reader) { create(:user) }

    it 'keeps the article read when only metadata changes' do
      article.mark_as_read!(for: reader)

      article.update!(title: 'Renamed article')

      expect(article.read_marks).to be_present
      expect(article.unread?(reader)).to be(false)
    end

    it 'makes the article unread when its text changes' do
      article.mark_as_read!(for: reader)

      article.update!(text: 'Revised article content')

      expect(article.read_marks).to be_empty
      expect(article.unread?(reader)).to be(true)
    end
  end

  describe '#send_notifications' do
    let(:article) do
      described_class.new(user: admin, category: category, title: 'Published article',
                          text: 'body', status: described_class::STATUS_PUBLISHED)
    end

    it 'notifies opted-in news readers' do
      recipient = create(:user)
      profiles = double('ProfileRelation')

      expect(Profile).to receive(:includes).with(:user).and_return(Profile)
      expect(Profile).to receive(:where).with('notify_news = 1').and_return(profiles)
      expect(profiles).to receive(:find_each).and_yield(double(user: recipient)).and_yield(double(user: nil))
      expect(Notifications).to receive(:news).with(recipient, article).once

      article.send_notifications
    end

    it 'notifies opted-in article readers' do
      article.category = create(:category, domain: Category::DOMAIN_ARTICLES)
      recipient = create(:user)
      profiles = double('ProfileRelation')

      expect(Profile).to receive(:includes).with(:user).and_return(Profile)
      expect(Profile).to receive(:where).with('notify_articles = 1').and_return(profiles)
      expect(profiles).to receive(:find_each).and_yield(double(user: recipient))
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
      article = legacy_bbcode_article('[b]bold[/b]')

      allow(article).to receive(:bbcode_to_html).with(article.text).and_return('<p>bold</p>')

      expect { article.save! }.to change { article.text_parsed }.from(nil).to('<p>bold</p>')
    end
  end

  describe '#record_view_count' do
    it 'does not create duplicate counts for the same ip' do
      article = create(:article, user: admin, category: category)

      expect do
        article.record_view_count('127.0.0.1', true)
        article.record_view_count('127.0.0.1', false)
      end.to change(article.view_counts, :count).by(1)
    end
  end

  describe 'XSS protection' do
    context 'with BBCode format' do
      it 'strips script tags from text' do
        article = legacy_bbcode_article('[b]bold[/b]<script>alert("xss")</script>')

        article.save!

        expect(article.text_parsed).not_to include('<script>')
        expect(article.text_parsed).not_to include('alert')
        expect(article.text_parsed).to include('<strong>bold</strong>')
      end

      it 'strips iframe tags from text' do
        article = legacy_bbcode_article('[b]text[/b]<iframe src="evil.com"></iframe>')

        article.save!

        expect(article.text_parsed).not_to include('<iframe')
      end

      it 'strips event handlers from text' do
        article = legacy_bbcode_article('[b]text[/b]<img src=x onerror="alert(1)">')

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

  def legacy_bbcode_article(text)
    article = create(:article, user: admin, category: category, text: 'Legacy article')
    # rubocop:disable Rails/SkipsModelValidations -- Legacy BBCode fixture; new BBCode articles are intentionally invalid.
    article.update_columns(text: text, text_coding: described_class::CODING_BBCODE, text_parsed: nil)
    # rubocop:enable Rails/SkipsModelValidations
    article.reload
  end
end
