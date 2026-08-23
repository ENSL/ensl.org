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
        fill_in 'article_title', with: article[:title]
        fill_in 'article_text', with: article[:text]
        click_button I18n.t('helpers.submit.post.create')

        expect(page).to have_content(I18n.t('flash.actions.create.notice', resource_name: Article.model_name.human))
      end

      it 'creates an article with a text length greater than 65535 bytes' do
        visit new_article_path
        expect(page).to have_selector('#article_title', wait: 5)
        fill_in 'article_title', with: article[:title]
        fill_in 'article_text', with: long_text
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

      it 'recommends Markdown, links its guide, and excludes BBCode' do
        visit new_article_path

        expect(page).to have_select('article_text_coding', selected: 'Markdown (recommended)')
        expect(page).to have_no_select('article_text_coding', with_options: ['BBCode'])
        expect(page).to have_link('Markdown guide', href: 'https://www.markdownguide.org/basic-syntax/')
        expect(page).to have_no_selector('.tox-tinymce')
      end

      it 'shows TinyMCE when HTML is selected before content editing' do
        visit new_article_path

        select 'Plain HTML', from: 'article_text_coding'

        expect(page).to have_selector('.tox-tinymce', wait: 5)
        expect(page).to have_select('article_text_coding', selected: 'Plain HTML', disabled: false)
      end

      it 'returns to the Markdown textarea when changed back before editing' do
        visit new_article_path
        select 'Plain HTML', from: 'article_text_coding'
        expect(page).to have_selector('.tox-tinymce', wait: 5)

        select 'Markdown (recommended)', from: 'article_text_coding'

        expect(page).to have_no_selector('.tox-tinymce', wait: 5)
        expect(page).to have_field('article_text', visible: true)
        expect(page).to have_select('article_text_coding', selected: 'Markdown (recommended)', disabled: false)
      end

      it 'locks Markdown after textarea editing begins' do
        visit new_article_path
        enabled_background = page.evaluate_script(<<~JAVASCRIPT)
          getComputedStyle(document.querySelector('#article_text_coding').closest('.select-wrapper')).backgroundColor
        JAVASCRIPT

        fill_in 'article_text', with: 'Started in Markdown'

        expect(page).to have_select('article_text_coding', selected: 'Markdown (recommended)', disabled: true)
        disabled_style = page.evaluate_script(<<~JAVASCRIPT)
          (() => {
            const select = document.querySelector('#article_text_coding')
            const wrapper = select.closest('.select-wrapper')
            return { background: getComputedStyle(wrapper).backgroundColor, cursor: getComputedStyle(select).cursor }
          })()
        JAVASCRIPT
        expect(disabled_style['background']).not_to eq(enabled_background)
        expect(disabled_style['cursor']).to eq('not-allowed')
      end

      it 'locks and preserves HTML after TinyMCE editing begins' do
        visit new_article_path
        fill_in 'article_title', with: article[:title]
        select 'Plain HTML', from: 'article_text_coding'
        expect(page).to have_selector('.tox-tinymce', wait: 5)

        fill_tinymce 'article_text', '<p>Started in HTML</p>'
        page.execute_script("tinymce.get('article_text').fire('input')")

        expect(page).to have_select('article_text_coding', selected: 'Plain HTML', disabled: true)
        click_button I18n.t('helpers.submit.post.create')
        expect(page).to have_content(I18n.t('flash.actions.create.notice', resource_name: Article.model_name.human))
        created = Article.order(:id).last
        expect(created.text_coding).to eq(Article::CODING_HTML)
        expect(created.text).to include('Started in HTML')
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

    it 'converts HTML to Markdown immediately after confirmation' do
      expect(page).to have_selector("form.article[action='#{article_path(html_article)}'] #article_text_coding")
      expect(page).to have_no_selector('form.article-format-conversion')

      accept_confirm(/irreversible/) do
        select 'Markdown', from: 'article_text_coding'
      end

      expect(page).to have_current_path(article_path(html_article))
      expect(html_article.reload.text_coding).to eq(Article::CODING_MARKDOWN)
      expect(html_article.text).to include('Existing content')
    end

    it 'does not convert when confirmation is dismissed' do
      dismiss_confirm do
        select 'Markdown', from: 'article_text_coding'
      end

      expect(page).to have_select('article_text_coding', selected: 'Plain HTML (current)')
      expect(html_article.reload.text_coding).to eq(Article::CODING_HTML)
    end

    it 'disables conversion after the content is edited' do
      page.execute_script(<<~JAVASCRIPT)
        const editor = tinymce.get('article_text')
        editor.setContent('<p>Changed content</p>')
        editor.fire('input')
      JAVASCRIPT

      expect(page).to have_select('article_text_coding', selected: 'Plain HTML (current)', disabled: true)
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

  describe 'navigating to an HTML editor with Turbo' do
    let!(:admin) { create(:user, :admin) }
    let!(:html_article) do
      create(:article, user: admin, category: category, text_coding: Article::CODING_HTML,
                       text: '<p>Existing content</p>')
    end

    it 'initializes TinyMCE without a full document reload' do
      sign_in_as(admin)
      visit article_path(html_article)
      page.execute_script('window.articleTurboNavigation = true')
      click_link 'Edit'

      expect(page).to have_current_path(edit_article_path(html_article))
      expect(page.evaluate_script('window.articleTurboNavigation')).to be(true)
      expect(page).to have_selector('.tox-tinymce', wait: 5)
      expect(page).to have_no_selector('.article-editor-status', visible: true)
    end
  end

  describe 'editing a legacy BBCode article' do
    let!(:admin) { create(:user, :admin) }
    let!(:legacy_article) do
      created = create(:article, user: admin, category: category, text: 'Legacy')
      # rubocop:disable Rails/SkipsModelValidations -- Legacy BBCode fixture; new BBCode articles are intentionally invalid.
      created.update_columns(text: '[b]Legacy[/b]', text_coding: Article::CODING_BBCODE)
      # rubocop:enable Rails/SkipsModelValidations
      created.reload
    end

    it 'converts BBCode to Markdown after confirmation' do
      sign_in_as(admin)
      visit edit_article_path(legacy_article)

      accept_confirm(/irreversible/) do
        select 'Markdown', from: 'article_text_coding'
      end

      expect(page).to have_current_path(article_path(legacy_article))
      expect(legacy_article.reload.text_coding).to eq(Article::CODING_MARKDOWN)
      expect(legacy_article.text).to include('**Legacy**')
    end
  end

  describe 'editing a Markdown article' do
    let!(:admin) { create(:user, :admin) }
    let!(:markdown_article) { create(:article, user: admin, category: category, text: '**Current Markdown**') }

    it 'shows the Markdown guide without offering another conversion' do
      sign_in_as(admin)
      visit edit_article_path(markdown_article)

      within 'form.article' do
        expect(page).to have_content('Markdown')
        expect(page).to have_link('Markdown guide', href: 'https://www.markdownguide.org/basic-syntax/')
        expect(page).to have_no_select('article_text_coding')
      end
    end
  end

  private

  def long_text
    (0..10_000).map { (0...8).map { rand(65..90).chr }.join }.join(' ') # 90008
  end
end
