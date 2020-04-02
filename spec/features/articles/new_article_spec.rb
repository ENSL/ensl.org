require 'rails_helper'

feature 'User creates new article', js: :true do
  let!(:category) { create(:category, domain: Category::DOMAIN_NEWS) }
  let(:article) { attributes_for(:article) }

  describe 'with valid Title, Content, Category' do
    context 'as a basic user' do
      let!(:user) { create(:user) }

      before do
        sign_in_as(user)
        visit new_article_path
      end

      it 'creates an article successfully' do
        skip
        fill_in attribute_translation(:article, :title), with: article[:title]
        fill_tinymce "article_text", article[:text]
        click_button I18n.t('helpers.submit.post.create')

        expect(page).to have_content(I18n.t('articles_create'))
      end

      it 'creates an article with a text length greater than 65535 bytes' do
        skip
        fill_in attribute_translation(:article, :title), with: article[:title]
        fill_tinymce "article_text", long_text
        click_button I18n.t('helpers.submit.post.create')

        expect(page).to have_content(I18n.t('articles_create'))
      end
    end
  end

  private

  def long_text
    (0..10000).map{ (0...8).map { (65 + rand(26)).chr }.join }.join(" ") # 90008
  end
end
