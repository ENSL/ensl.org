require 'rails_helper'

RSpec.describe 'GroupsController', type: :request do
  let(:admin) { create(:user, :admin) }
  let(:user) { create(:user) }

  def login_as(account)
    post '/users/login', params: { login: { username: account.username, password: account.raw_password } }
  end

  describe 'GET /groups/new' do
    it 'allows admins' do
      login_as(admin)

      get '/groups/new'

      expect(response).to have_http_status(:ok)
      expect(response).to render_template(:new)
    end

    it 'returns 403 for non-admins' do
      login_as(user)

      get '/groups/new'

      expect(response).to have_http_status(:forbidden)
    end
  end

  describe 'POST /groups' do
    it 'creates a group for admins' do
      login_as(admin)

      expect do
        post '/groups', params: { group: { name: 'Content Mods' } }
      end.to change(Group, :count).by(1)

      expect(response).to redirect_to(group_path(Group.order(:id).last))
      expect(Group.order(:id).last.founder).to eq(admin)
    end

    it 'returns 422 for invalid data' do
      login_as(admin)

      expect do
        post '/groups', params: { group: { name: '' } }
      end.not_to change(Group, :count)

      expect(response).to have_http_status(422)
      expect(response).to render_template(:new)
    end
  end

  describe 'PATCH /groups/:id' do
    let(:group) { create(:group, name: 'Original') }

    it 'updates a group for admins' do
      login_as(admin)

      patch "/groups/#{group.id}", params: { group: { name: 'Renamed' } }

      expect(response).to redirect_to(group_path(group))
      expect(group.reload.name).to eq('Renamed')
    end

    it 'returns 422 when the update is invalid' do
      login_as(admin)

      patch "/groups/#{group.id}", params: { group: { name: '' } }

      expect(response).to have_http_status(422)
      expect(response).to render_template(:edit)
      expect(group.reload.name).to eq('Original')
    end

    it 'returns 403 for non-admins' do
      login_as(user)

      patch "/groups/#{group.id}", params: { group: { name: 'Blocked' } }

      expect(response).to have_http_status(:forbidden)
      expect(group.reload.name).to eq('Original')
    end
  end

  describe 'DELETE /groups/:id' do
    it 'destroys a custom group for admins' do
      group = create(:group)
      login_as(admin)

      expect do
        delete "/groups/#{group.id}"
      end.to change(Group, :count).by(-1)

      expect(response).to redirect_to(groups_path)
    end

    it 'returns 403 for protected groups even for admins' do
      login_as(admin)
      protected_group = Group.find(Group::ADMINS)

      expect do
        delete "/groups/#{protected_group.id}"
      end.not_to change(Group, :count)

      expect(response).to have_http_status(:forbidden)
    end
  end
end
