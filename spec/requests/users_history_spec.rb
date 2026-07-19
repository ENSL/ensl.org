# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Users history', type: :request do
  let!(:admin) { create(:user, :admin) }
  let!(:member) { create(:user) }

  def login_as(account)
    post '/sessions/login', params: { login: { username: account.username, password: account.raw_password } }
  end

  describe 'GET /users/:id/history' do
    it 'renders the history page for admins with versioned user data' do
      user = create(:user, username: 'legacy_name', steamid: '0:1:234', lastip: '4.4.4.4')
      user.update!(username: 'current_name', steamid: '0:1:345', lastip: '5.5.5.5')

      login_as(admin)
      get "/users/#{user.id}/history"

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('legacy_name')
      expect(response.body).to include('0:1:234')
      expect(response.body).to include('4.4.4.4')
      expect(response.body).to include('Date')
    end

    it 'returns 403 for non-admin users' do
      user = create(:user)

      login_as(member)
      get "/users/#{user.id}/history"

      expect(response).to have_http_status(:forbidden)
    end
  end
end
