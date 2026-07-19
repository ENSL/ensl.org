# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'MapsController', type: :request do
  let(:admin) { create(:user, :admin) }
  let(:user) { create(:user) }

  describe 'GET /maps' do
    it 'renders the map listing' do
      create(:map, name: 'ns_tram')

      get '/maps'

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('ns_tram')
    end
  end

  describe 'GET /maps/:id' do
    it 'renders a map page' do
      map = create(:map, name: 'ns_veil')

      get "/maps/#{map.id}"

      expect(response).to have_http_status(:ok)
      expect(response).to render_template(:show)
    end
  end

  describe 'GET /maps/new' do
    it 'allows admins' do
      login_as(admin)

      get '/maps/new'

      expect(response).to have_http_status(:ok)
      expect(response).to render_template(:new)
    end

    it 'returns 403 for non-admin users' do
      login_as(user)

      get '/maps/new'

      expect(response).to have_http_status(:forbidden)
    end
  end

  describe 'GET /maps/:id/edit' do
    it 'allows admins' do
      map = create(:map)
      login_as(admin)

      get "/maps/#{map.id}/edit"

      expect(response).to have_http_status(:ok)
      expect(response).to render_template(:edit)
    end

    it 'returns 403 for non-admin users' do
      map = create(:map)
      login_as(user)

      get "/maps/#{map.id}/edit"

      expect(response).to have_http_status(:forbidden)
    end
  end

  describe 'POST /maps' do
    let(:valid_params) { { map: { name: 'ns_summit', download: 'https://example.com/summit.zip' } } }

    it 'creates a map for admins' do
      login_as(admin)

      expect do
        post '/maps', params: valid_params
      end.to change(Map, :count).by(1)

      expect(response).to redirect_to(map_path(Map.order(:id).last))
    end

    it 're-renders new for invalid map data' do
      login_as(admin)

      expect do
        post '/maps', params: { map: { name: 'a' * 21, download: 'https://example.com/summit.zip' } }
      end.not_to change(Map, :count)

      expect(response).to have_http_status(:ok)
      expect(response).to render_template(:new)
    end

    it 'returns 403 for non-admin users' do
      login_as(user)

      expect do
        post '/maps', params: valid_params
      end.not_to change(Map, :count)

      expect(response).to have_http_status(:forbidden)
    end
  end

  describe 'PATCH /maps/:id' do
    let(:map) { create(:map, name: 'ns_origin') }

    it 'updates maps for admins' do
      login_as(admin)

      patch "/maps/#{map.id}", params: { map: { name: 'ns_origin_reworked' } }

      expect(response).to redirect_to(map_path(map))
      expect(map.reload.name).to eq('ns_origin_reworked')
    end

    it 're-renders edit for invalid updates' do
      login_as(admin)

      patch "/maps/#{map.id}", params: { map: { name: 'b' * 21 } }

      expect(response).to have_http_status(:ok)
      expect(response).to render_template(:edit)
      expect(map.reload.name).to eq('ns_origin')
    end

    it 'returns 403 for non-admin users' do
      login_as(user)

      patch "/maps/#{map.id}", params: { map: { name: 'blocked_name' } }

      expect(response).to have_http_status(:forbidden)
      expect(map.reload.name).to eq('ns_origin')
    end
  end

  describe 'DELETE /maps/:id' do
    it 'soft-deletes maps for admins' do
      map = create(:map)
      login_as(admin)

      expect do
        delete "/maps/#{map.id}"
      end.not_to change(Map, :count)

      expect(response).to redirect_to(maps_path)
      expect(map.reload.deleted).to be true
    end

    it 'returns 403 for non-admin users' do
      map = create(:map)
      login_as(user)

      delete "/maps/#{map.id}"

      expect(response).to have_http_status(:forbidden)
      expect(map.reload.deleted).to be false
    end
  end
end
