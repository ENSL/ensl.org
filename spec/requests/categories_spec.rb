require 'rails_helper'

RSpec.describe 'CategoriesController', type: :request do
  let(:admin) { create(:user, :admin) }
  let(:user) { create(:user) }

  describe 'GET /categories' do
    it 'renders the categories index' do
      create(:category, name: 'Articles category')

      get '/categories'

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('Articles category')
    end
  end

  describe 'GET /categories/:id' do
    it 'renders article listings for article categories' do
      category = create(:category, domain: Category::DOMAIN_ARTICLES)
      article = create(:article,
                       user: create(:user, :admin),
                       category: category,
                       title: 'Visible article',
                       status: Article::STATUS_PUBLISHED)

      get "/categories/#{category.id}"

      expect(response).to have_http_status(:ok)
      expect(response.body).to include(article.title)
    end

    it 'marks article categories as read for logged in users' do
      category = create(:category, domain: Category::DOMAIN_ARTICLES)
      article = create(:article,
                       user: create(:user, :admin),
                       category: category,
                       title: 'Read-tracked article',
                       status: Article::STATUS_PUBLISHED)
      login_as(user)
      expect_any_instance_of(Category).to receive(:mark_as_read!).with(for: user)

      get "/categories/#{category.id}"

      expect(response).to have_http_status(:ok)
      expect(response.body).to include(article.title)
    end

    it 'returns no content for non-article categories', :expect_log_error do
      category = create(:category, domain: Category::DOMAIN_FORUMS)

      get "/categories/#{category.id}"

      expect(response).to have_http_status(:not_acceptable)
    end
  end

  describe 'GET /categories/new' do
    it 'allows admins' do
      login_as(admin)

      get '/categories/new'

      expect(response).to have_http_status(:ok)
      expect(response).to render_template(:new)
    end

    it 'returns 403 for non-admins' do
      login_as(user)

      get '/categories/new'

      expect(response).to have_http_status(:forbidden)
    end
  end

  describe 'POST /categories' do
    it 'creates a category for admins and aligns sort with id' do
      login_as(admin)

      expect do
        post '/categories', params: { category: { name: 'Created category', domain: Category::DOMAIN_NEWS, sort: 0 } }
      end.to change(Category, :count).by(1)

      category = Category.order(:id).last
      expect(response).to redirect_to(categories_path)
      expect(category.sort).to eq(category.id)
    end

    it 'renders new for invalid data' do
      login_as(admin)

      expect do
        post '/categories', params: { category: { name: '', domain: -1, sort: 0 } }
      end.not_to change(Category, :count)

      expect(response).to have_http_status(422)
      expect(response).to render_template(:new)
    end

    it 'returns 403 for non-admins' do
      login_as(user)

      expect do
        post '/categories', params: { category: { name: 'Blocked category', domain: Category::DOMAIN_NEWS, sort: 0 } }
      end.not_to change(Category, :count)

      expect(response).to have_http_status(:forbidden)
    end
  end

  describe 'PATCH /categories/:id' do
    let!(:category) { create(:category, name: 'Original category') }

    it 'updates a category for admins' do
      login_as(admin)

      patch "/categories/#{category.id}",
            params: { category: { name: 'Renamed category', domain: category.domain, sort: category.sort } }

      expect(response).to redirect_to(categories_path)
      expect(category.reload.name).to eq('Renamed category')
    end

    it 'renders edit for invalid data' do
      login_as(admin)

      patch "/categories/#{category.id}", params: { category: { name: '', domain: -1, sort: category.sort } }

      expect(response).to have_http_status(422)
      expect(response).to render_template(:edit)
      expect(category.reload.name).to eq('Original category')
    end

    it 'returns 403 for non-admins' do
      login_as(user)

      patch "/categories/#{category.id}",
            params: { category: { name: 'Blocked', domain: category.domain, sort: category.sort } }

      expect(response).to have_http_status(:forbidden)
      expect(category.reload.name).to eq('Original category')
    end
  end

  describe 'PATCH /categories/:id/up' do
    it 'moves the category up for admins' do
      first_category = create(:category, domain: Category::DOMAIN_NEWS, sort: 1)
      second_category = create(:category, domain: Category::DOMAIN_NEWS, sort: 2)
      login_as(admin)

      patch "/categories/#{second_category.id}/up"

      expect(response).to redirect_to(categories_path)
      expect(second_category.reload.sort).to eq(1)
      expect(first_category.reload.sort).to eq(2)
    end

    it 'returns 403 for non-admins' do
      category = create(:category)
      login_as(user)

      patch "/categories/#{category.id}/up"

      expect(response).to have_http_status(:forbidden)
    end
  end

  describe 'PATCH /categories/:id/down' do
    it 'moves the category down for admins' do
      first_category = create(:category, domain: Category::DOMAIN_NEWS, sort: 1)
      second_category = create(:category, domain: Category::DOMAIN_NEWS, sort: 2)
      login_as(admin)

      patch "/categories/#{first_category.id}/down"

      expect(response).to redirect_to(categories_path)
      expect(first_category.reload.sort).to eq(2)
      expect(second_category.reload.sort).to eq(1)
    end

    it 'returns 403 for non-admins' do
      category = create(:category)
      login_as(user)

      patch "/categories/#{category.id}/down"

      expect(response).to have_http_status(:forbidden)
    end
  end

  describe 'DELETE /categories/:id' do
    it 'destroys a category for admins' do
      category = create(:category)
      login_as(admin)

      expect do
        delete "/categories/#{category.id}"
      end.to change(Category, :count).by(-1)

      expect(response).to redirect_to(categories_path)
    end

    it 'returns 403 for non-admins' do
      category = create(:category)
      login_as(user)

      expect do
        delete "/categories/#{category.id}"
      end.not_to change(Category, :count)

      expect(response).to have_http_status(:forbidden)
    end
  end
end
