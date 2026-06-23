# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'ArticlesController', type: :request do
  let!(:category) { create(:category, domain: Category::DOMAIN_NEWS, name: 'News Category') }
  let!(:valid_params) { attributes_for(:article).merge(category_id: category.id) }
  let!(:invalid_params) { valid_params.merge(title: 'a' * 151) }
  let!(:admin) { create(:user, :admin) }
  let!(:user) { create(:user) }
  let!(:article) { create(:article, category: category, user: admin) }

  def login_as(account)
    post '/users/login', params: { login: { username: account.username, password: account.raw_password } }
  end

  describe 'GET /articles' do
    it 'renders the index page' do
      get '/articles'

      expect(response).to have_http_status(:ok)
      expect(response).to render_template(:index)
    end

    it 'shows the articles heading' do
      get '/articles'

      expect(response.body).to include('Articles')
    end
  end

  describe 'GET /articles/news' do
    it 'renders the news index' do
      get '/articles/news'

      expect(response).to have_http_status(:ok)
      expect(response).to render_template(:news_index)
    end

    it 'renders the newest poll in sidebar widget' do
      old_poll = Poll.new(question: 'Old poll question')
      old_poll.options.build(option: 'Old A')
      old_poll.options.build(option: 'Old B')
      old_poll.save!
      old_poll.update_column(:created_at, 2.days.ago)

      newest_poll = Poll.new(question: 'Newest poll question')
      newest_poll.options.build(option: 'New A')
      newest_poll.options.build(option: 'New B')
      newest_poll.save!

      get '/articles/news'

      expect(response).to have_http_status(:ok)
      expect(response.body).to include(newest_poll.question)
      expect(response.body).not_to include(old_poll.question)
    end
  end

  describe 'GET /articles/news/archive' do
    it 'renders the news archive' do
      get '/articles/news/archive'

      expect(response).to have_http_status(:ok)
      expect(response).to render_template(:news_archive)
    end
  end

  describe 'GET /articles/news/admin' do
    it 'renders the admin page for admins' do
      login_as(admin)

      get '/articles/news/admin'

      expect(response).to have_http_status(:ok)
      expect(response).to render_template(:admin)
    end

    it 'returns 403 for non-admins' do
      login_as(user)

      get '/articles/news/admin'

      expect(response).to have_http_status(:forbidden)
    end
  end

  describe 'GET /articles/:id' do
    it 'renders published articles for guests' do
      get "/articles/#{article.id}"

      expect(response).to have_http_status(:ok)
      expect(response).to render_template(:show)
    end

    it 'renders published articles for signed in users' do
      login_as(user)

      get "/articles/#{article.id}"

      expect(response).to have_http_status(:ok)
      expect(response).to render_template(:show)
    end
  end

  describe 'GET /articles/new' do
    it 'renders the new form for admins' do
      login_as(admin)

      get '/articles/new'

      expect(response).to have_http_status(:ok)
      expect(response).to render_template(:new)
    end

    it 'returns 403 for guests' do
      get '/articles/new'

      expect(response).to have_http_status(:forbidden)
    end
  end

  describe 'GET /articles/:id/edit' do
    it 'renders edit for admins' do
      login_as(admin)

      get "/articles/#{article.id}/edit"

      expect(response).to have_http_status(:ok)
      expect(response).to render_template(:edit)
    end

    it 'returns 403 for non-admins' do
      login_as(user)

      get "/articles/#{article.id}/edit"

      expect(response).to have_http_status(:forbidden)
    end
  end

  describe 'POST /articles' do
    it 'creates an article with valid params' do
      login_as(admin)

      expect do
        post '/articles', params: { article: valid_params }
      end.to change(Article, :count).by(1)

      created_article = Article.order(:id).last
      expect(response).to redirect_to(article_path(created_article))
      expect(created_article.title).to eq(valid_params[:title])
    end

    it 're-renders new with invalid params' do
      login_as(admin)

      expect do
        post '/articles', params: { article: invalid_params }
      end.not_to change(Article, :count)

      expect(response).to have_http_status(:unprocessable_content)
      expect(response).to render_template(:new)
    end

    it 'returns 403 for guests' do
      expect do
        post '/articles', params: { article: valid_params }
      end.not_to change(Article, :count)

      expect(response).to have_http_status(:forbidden)
    end
  end

  describe 'PATCH /articles/:id' do
    it 'updates the article with valid params' do
      login_as(admin)

      patch "/articles/#{article.id}", params: { article: valid_params.merge(title: 'Updated title') }

      expect(response).to redirect_to(article_path(article))
      expect(article.reload.title).to eq('Updated title')
    end

    it 're-renders edit with invalid params' do
      login_as(admin)

      patch "/articles/#{article.id}", params: { article: invalid_params }

      expect(response).to have_http_status(:unprocessable_content)
      expect(response).to render_template(:edit)
      expect(article.reload.title).not_to eq(invalid_params[:title])
    end

    it 'returns 403 for non-admins' do
      login_as(user)

      patch "/articles/#{article.id}", params: { article: valid_params.merge(title: 'Blocked update') }

      expect(response).to have_http_status(:forbidden)
      expect(article.reload.title).not_to eq('Blocked update')
    end
  end

  describe 'DELETE /articles/:id' do
    it 'deletes the article for admins' do
      login_as(admin)

      expect do
        delete "/articles/#{article.id}", headers: { 'HTTP_REFERER' => '/articles' }
      end.to change(Article, :count).by(-1)

      expect(response).to redirect_to('/articles')
    end

    it 'does not delete the article without access' do
      login_as(user)

      expect do
        delete "/articles/#{article.id}"
      end.not_to change(Article, :count)
    end
  end
end
