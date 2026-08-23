# frozen_string_literal: true

require 'rails_helper'

feature 'User creates new article', js: true do
  let!(:category) { create(:category, domain: Category::DOMAIN_NEWS) }
  let(:article) { attributes_for(:article) }

  describe 'with valid Title, Content, Category' do
    context 'as a basic user' do
      let!(:user) { create(:user) }

      before do
        sign_in_as(user)
      end

      it 'creates an article successfully' do
        visit new_article_path
        expect(page).to have_selector('#article_title', wait: 5)
        expect(page).to have_selector('.tox-tinymce', wait: 5)
        expect(page).to have_no_selector('.article-editor-status', visible: true)
        fill_in 'article_title', with: article[:title]
        expect(page).to have_selector('#article_text', visible: :all, wait: 5)
        fill_tinymce 'article_text', article[:text]
        click_button I18n.t('helpers.submit.post.create')

        expect(page).to have_content(I18n.t('flash.actions.create.notice', resource_name: Article.model_name.human))
      end

      it 'creates an article with a text length greater than 65535 bytes' do
        visit new_article_path
        expect(page).to have_selector('#article_title', wait: 5)
        fill_in 'article_title', with: article[:title]
        expect(page).to have_selector('#article_text', visible: :all, wait: 5)
        fill_tinymce 'article_text', long_text
        click_button I18n.t('helpers.submit.post.create')

        expect(page).to have_content(I18n.t('flash.actions.create.notice', resource_name: Article.model_name.human))
      end

      # TODO: add more fancier formatting tests (images, links, etc)
      it 'groups categories by alphabetized domain and category name' do
        create(:category, domain: Category::DOMAIN_ARTICLES, name: 'Zulu')
        create(:category, domain: Category::DOMAIN_ARTICLES, name: 'Alpha')
        visit new_article_path

        groups = page.all('#article_category_id optgroup').map do |group|
          [group[:label], group.all('option').map(&:text)]
        end

        expect(groups.map(&:first)).to eq(groups.map(&:first).sort)
        expect(groups.to_h.fetch('Articles')).to eq(%w[Alpha Zulu])
      end

      it 'initializes the editor after following a Turbo link' do
        visit articles_path
        expect(page.evaluate_script('typeof window.tinymce')).to eq('object')
        expect(page.evaluate_script('window.TinyMCERails.configuration.articles != null')).to be(true)

        page.execute_script('window.articleTurboNavigation = true')
        click_link 'New Article'

        expect(page).to have_current_path(new_article_path)
        expect(page.evaluate_script('window.articleTurboNavigation')).to be(true)
        expect(page).to have_selector('.tox-tinymce', wait: 5)
        expect(page).to have_no_selector('.article-editor-status', visible: true)
      end
    end
  end

  describe 'editing an HTML article' do
    let!(:admin) { create(:user, :admin) }
    let!(:article_directory) { create(:directory, :articles) }
    let!(:html_article) do
      create(:article, user: admin, category: category, text_coding: Article::CODING_HTML,
                       text: '<p>Existing content</p>')
    end

    before do
      sign_in_as(admin)
      visit edit_article_path(html_article)
      expect(page).to have_selector('.tox-tinymce', wait: 5)
    end

    it 'uses the full layout and provides link, image, and table controls' do
      expect(page).to have_no_selector('#sidebar')
      expect(page).to have_no_selector('.article-editor-status', visible: true)
      expect(page).to have_selector('button[data-mce-name="link"]')
      expect(page).to have_selector('button[data-mce-name="image"]')
      expect(page).to have_selector('button[data-mce-name="table"]')

      submit_bottom = page.evaluate_script(
        "document.querySelector('form.article input[type=submit]').getBoundingClientRect().bottom"
      )
      footer_top = page.evaluate_script("document.querySelector('footer').getBoundingClientRect().top")
      expect(footer_top).to be > submit_bottom
    end

    it 'uploads an image without navigation and inserts it into the editor' do
      upload = Tempfile.new(['article-image', '.png'])
      upload.binmode
      upload.write("\x89PNG\r\n\x1a\n")
      upload.close

      within '#article_file_upload' do
        attach_file 'data_file_name', upload.path
        click_button 'Create'
      end

      notice = I18n.t('flash.actions.create.notice', resource_name: DataFile.model_name.human)
      expect(page).to have_content(notice, wait: 5)
      created_file = DataFile.order(:id).last
      expect(page).to have_current_path(edit_article_path(html_article))
      expect(page).to have_selector("#data_file_#{created_file.id}", wait: 5)
      expect(page.evaluate_script("tinymce.get('article_text').getContent()"))
        .to include("<img src=\"#{created_file.url}\"")
    ensure
      FileUtils.rm_f(created_file.location) if created_file&.location
      upload&.unlink
    end
  end

  private

  def long_text
    (0..10_000).map { (0...8).map { rand(65..90).chr }.join }.join(' ') # 90008
  end
end
