# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'ServersController', type: :request do
  let(:admin) { create(:user, :admin) }
  let(:owner) { create(:user) }
  let(:user) { create(:user) }

  describe 'GET /servers' do
    it 'renders the listing' do
      create(:server, :active, name: 'Alpha Server')

      get '/servers'

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('Alpha Server')
    end
  end

  describe 'GET /servers/new' do
    it 'allows logged in users' do
      login_as(user)

      get '/servers/new'

      expect(response).to have_http_status(:ok)
      expect(response).to render_template(:new)
    end

    it 'returns 403 for guests' do
      get '/servers/new'

      expect(response).to have_http_status(:forbidden)
    end
  end

  describe 'GET /servers/:id' do
    it 'renders active servers' do
      server = create(:server, :active)

      get "/servers/#{server.id}"

      expect(response).to have_http_status(:ok)
      expect(response).to render_template(:show)
    end

    it 'returns 404 for inactive servers when the user cannot update them' do
      server = create(:server, :inactive, user: owner)
      login_as(user)

      get "/servers/#{server.id}"

      expect(response).to have_http_status(:not_found)
    end
  end

  describe 'GET /servers/:id/edit' do
    it 'allows the owner to edit an inactive server' do
      server = create(:server, :inactive, user: owner)
      login_as(owner)

      get "/servers/#{server.id}/edit"

      expect(response).to have_http_status(:ok)
      expect(response).to render_template(:edit)
    end
  end

  describe 'POST /servers' do
    let(:server_params) { attributes_for(:server) }

    it 'creates a server for logged in users' do
      login_as(user)

      expect do
        post '/servers', params: { server: server_params }
      end.to change(Server, :count).by(1)

      expect(response).to redirect_to(server_path(Server.order(:id).last))
      expect(Server.order(:id).last.user).to eq(user)
    end

    it 'renders new for invalid data' do
      login_as(user)

      expect do
        post '/servers', params: { server: server_params.merge(name: '', ip: 'bad-ip') }
      end.not_to change(Server, :count)

      expect(response).to have_http_status(422)
      expect(response).to render_template(:new)
    end

    it 'returns 403 for guests' do
      expect do
        post '/servers', params: { server: server_params }
      end.not_to change(Server, :count)

      expect(response).to have_http_status(:forbidden)
    end
  end

  describe 'PATCH /servers/:id' do
    let!(:server) { create(:server, user: owner, name: 'Original name') }

    it 'updates the server for its owner' do
      login_as(owner)

      patch "/servers/#{server.id}",
            params: { server: { name: 'Updated name', dns: server.dns, ip: server.ip, port: server.port } }

      expect(response).to redirect_to(server_path(server))
      expect(server.reload.name).to eq('Updated name')
    end

    it 'renders edit when the update is invalid' do
      login_as(owner)

      patch "/servers/#{server.id}", params: { server: { name: '', dns: server.dns, ip: 'invalid', port: server.port } }

      expect(response).to have_http_status(422)
      expect(response).to render_template(:edit)
      expect(server.reload.name).to eq('Original name')
    end

    it 'returns 403 for other users' do
      login_as(user)

      patch "/servers/#{server.id}",
            params: { server: { name: 'Blocked', dns: server.dns, ip: server.ip, port: server.port } }

      expect(response).to have_http_status(:forbidden)
      expect(server.reload.name).to eq('Original name')
    end
  end

  describe 'DELETE /servers/:id' do
    it 'destroys servers for admins' do
      server = create(:server, user: owner)
      login_as(admin)

      expect do
        delete "/servers/#{server.id}"
      end.to change(Server, :count).by(-1)

      expect(response).to redirect_to(servers_path)
    end

    it 'returns 403 for non-admins' do
      server = create(:server, user: owner)
      login_as(owner)

      expect do
        delete "/servers/#{server.id}"
      end.not_to change(Server, :count)

      expect(response).to have_http_status(:forbidden)
    end
  end
end
