require 'rails_helper'

RSpec.describe 'VersionsController', type: :request do
  let!(:article) { create(:article) }
  let!(:admin) { create(:user, :admin) }

  def login_as(account)
    post '/users/login', params: { login: { username: account.username, password: account.raw_password } }
  end

  describe 'GET /articles/:article_id/versions' do
    it 'renders the article history when versions are available' do
      get "/articles/#{article.id}/versions"

      expect(response).to have_http_status(:ok)
      expect(response).to render_template('articles/history')
    end

    it 'returns 404 when article version table is unavailable' do
      allow(ActiveRecord::Base.connection).to receive(:data_source_exists?).with('article_versions').and_return(false)

      get "/articles/#{article.id}/versions"

      expect(response).to have_http_status(:not_found)
    end
  end

  describe 'GET /articles/:article_id/versions/:id' do
    let!(:versioned_article) do
      article.update!(title: 'Updated title')
      article.reload
    end

    it 'renders the version for admins' do
      login_as(admin)

      get "/articles/#{versioned_article.id}/versions/#{versioned_article.versions.last.id}"

      expect(response).to have_http_status(:ok)
      expect(response).to render_template('articles/version')
    end

    it 'returns 403 for non-admins' do
      get "/articles/#{versioned_article.id}/versions/#{versioned_article.versions.last.id}"

      expect(response).to have_http_status(:forbidden)
    end
  end

  describe 'PATCH /articles/:article_id/versions/:id' do
    let!(:original_title) { article.title }
    let!(:versioned_article) do
      article.update!(title: 'Updated title')
      article.reload
    end

    it 'reverts to the selected version for admins' do
      login_as(admin)

      patch "/articles/#{versioned_article.id}/versions/#{versioned_article.versions.first.id}"

      expect(response).to redirect_to(article_path(versioned_article))
      expect(versioned_article.reload.title).to eq(original_title)
      expect(flash[:notice]).to be_present
    end

    it 'returns 403 when the user cannot update the article' do
      patch "/articles/#{versioned_article.id}/versions/#{versioned_article.versions.first.id}"

      expect(response).to have_http_status(:forbidden)
    end
  end
end