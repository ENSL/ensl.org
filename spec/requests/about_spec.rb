# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'AboutController', type: :request do
  def login_as(account)
    post '/sessions/login', params: { login: { username: account.username, password: account.raw_password } }
  end

  describe 'GET /about/staff' do
    it 'renders the staff page' do
      get '/about/staff'

      expect(response).to have_http_status(:ok)
      expect(response).to render_template(:staff)
    end
  end

  describe 'GET /about/adminpanel' do
    let(:admin) { create(:user, :admin) }
    let(:user) { create(:user) }

    it 'renders for admins' do
      login_as(admin)

      get '/about/adminpanel'

      expect(response).to have_http_status(:ok)
      expect(response).to render_template(:adminpanel)
    end

    it 'returns 403 for non-admins' do
      login_as(user)

      get '/about/adminpanel'

      expect(response).to have_http_status(:forbidden)
    end

    it 'returns 403 for guests' do
      get '/about/adminpanel'

      expect(response).to have_http_status(:forbidden)
    end

    it 'shows root directory links when a root directory exists' do
      root = create(:directory, :root)
      login_as(admin)

      get '/about/adminpanel'

      expect(response).to have_http_status(:ok)
      expect(response.body).to include(reconcile_directory_path(root))
      expect(response.body).to include(directory_path(root))
    end

    it 'hides root directory links when there are no directories' do
      Directory.delete_all
      login_as(admin)

      get '/about/adminpanel'

      expect(response).to have_http_status(:ok)
      expect(response.body).not_to include('Recreate Root')
      expect(response.body).not_to include('Files Admin')
    end
  end

  describe 'GET /about/statistics' do
    it 'renders the statistics page' do
      get '/about/statistics'

      expect(response).to have_http_status(:ok)
      expect(response).to render_template(:statistics)
    end
  end
end
