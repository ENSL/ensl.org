# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'CustomUrlsController', type: :request do
  let(:admin) { create(:user, :admin) }
  let(:user) { create(:user) }

  describe 'GET /custom_urls' do
    it 'renders the administrate page for admins' do
      login_as(admin)

      get '/custom_urls'

      expect(response).to have_http_status(:ok)
      expect(response).to render_template(:administrate)
    end

    it 'returns 403 for non-admins' do
      login_as(user)

      get '/custom_urls'

      expect(response).to have_http_status(:forbidden)
    end
  end

  describe 'POST /custom_urls' do
    let!(:article) { create(:article, title: 'Linked article') }

    it 'creates a custom url for admins' do
      login_as(admin)

      expect do
        post '/custom_urls', params: { custom_url: { name: 'linked-url', article_id: article.id } }
      end.to change(CustomUrl, :count).by(1)

      expect(response).to redirect_to(custom_urls_path)
      expect(CustomUrl.order(:id).last.article).to eq(article)
    end

    it 'renders administrate for invalid data' do
      login_as(admin)

      expect do
        post '/custom_urls', params: { custom_url: { name: '', article_id: nil } }
      end.not_to change(CustomUrl, :count)

      expect(response).to have_http_status(422)
      expect(response).to render_template(:administrate)
    end

    it 'returns 403 for non-admins' do
      login_as(user)

      expect do
        post '/custom_urls', params: { custom_url: { name: 'blocked-url', article_id: article.id } }
      end.not_to change(CustomUrl, :count)

      expect(response).to have_http_status(:forbidden)
    end
  end

  describe 'GET /:name' do
    it 'renders the linked article for published articles' do
      article = create(:article, user: create(:user, :admin), title: 'Published article', status: Article::STATUS_PUBLISHED)
      custom_url = CustomUrl.create!(name: 'published', article: article)

      get "/#{custom_url.name}"

      expect(response).to have_http_status(:ok)
      expect(response).to render_template('articles/show')
      expect(response.body).to include('Published article')
    end

    it 'returns 403 when the article is not visible' do
      draft_author = create(:user)
      article = create(:article, user: draft_author, status: Article::STATUS_DRAFT)
      custom_url = CustomUrl.create!(name: 'draft-link', article: article)

      get "/#{custom_url.name}"

      expect(response).to have_http_status(:forbidden)
    end

    it 'returns 404 for text format when slug is missing' do
      get '/ads-txt.txt'

      expect(response).to have_http_status(:not_found)
      expect(response.body).to eq('')
    end

    it 'returns 404 when the custom url points to a deleted article' do
      article = create(:article)
      custom_url = CustomUrl.create!(name: 'slug-test', article_id: article.id)
      article.destroy!

      get "/#{custom_url.name}"

      expect(response).to have_http_status(:not_found)
    end
  end

  describe 'PATCH /custom_urls/:id' do
    let!(:article) do
      create(:article, user: create(:user, :admin), title: 'Original article', status: Article::STATUS_PUBLISHED)
    end
    let!(:replacement_article) do
      create(:article, user: create(:user, :admin), title: 'Replacement title', status: Article::STATUS_PUBLISHED)
    end
    let!(:custom_url) { CustomUrl.create!(name: 'original', article: article) }

    it 'updates the custom url for admins' do
      login_as(admin)

      patch "/custom_urls/#{custom_url.id}",
            params: { custom_url: { name: 'updated', article_id: replacement_article.id } },
            as: :json

      expect(response).to have_http_status(:ok)
      expect(custom_url.reload.name).to eq('updated')
      expect(custom_url.article).to eq(replacement_article)

      body = JSON.parse(response.body)
      expect(body['obj']).to eq({ 'name' => 'updated', 'title' => 'Replacement title' })
    end

    it 'returns validation errors for invalid data' do
      login_as(admin)

      patch "/custom_urls/#{custom_url.id}",
            params: { custom_url: { name: '', article_id: nil } },
            as: :json

      expect(response).to have_http_status(422)
      expect(custom_url.reload.name).to eq('original')

      body = JSON.parse(response.body)
      expect(body['errors']).not_to be_empty
    end

    it 'returns 403 for non-admins' do
      login_as(user)

      patch "/custom_urls/#{custom_url.id}",
            params: { custom_url: { name: 'blocked', article_id: replacement_article.id } },
            as: :json

      expect(response).to have_http_status(:forbidden)
      expect(custom_url.reload.name).to eq('original')
    end
  end

  describe 'DELETE /custom_urls/:id' do
    it 'destroys a custom url for admins over html' do
      custom_url = CustomUrl.create!(name: 'delete-me', article: create(:article))
      login_as(admin)

      expect do
        delete "/custom_urls/#{custom_url.id}"
      end.to change(CustomUrl, :count).by(-1)

      expect(response).to redirect_to(custom_urls_path)
    end

    it 'destroys a custom url for admins over json' do
      custom_url = CustomUrl.create!(name: 'deletejson', article: create(:article))
      login_as(admin)

      expect do
        delete "/custom_urls/#{custom_url.id}", as: :json
      end.to change(CustomUrl, :count).by(-1)

      expect(response).to have_http_status(:ok)
      expect(JSON.parse(response.body)['status']).to eq(200)
    end

    it 'returns 403 for non-admins' do
      custom_url = CustomUrl.create!(name: 'keep-this', article: create(:article))
      login_as(user)

      expect do
        delete "/custom_urls/#{custom_url.id}"
      end.not_to change(CustomUrl, :count)

      expect(response).to have_http_status(:forbidden)
    end
  end
end
