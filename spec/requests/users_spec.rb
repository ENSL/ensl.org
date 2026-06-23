# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'UsersController', type: :request do
  let(:user) { create(:user) }
  let(:admin) { create(:user, :admin) }

  def login_as(account)
    post '/users/login', params: { login: { username: account.username, password: account.raw_password } }
  end

  describe 'GET /users' do
    it 'renders the index page with users' do
      indexed_user = create(:user, username: 'VisibleUser')

      get '/users'

      expect(response).to have_http_status(:ok)
      expect(response).to render_template(:index)
      expect(response.body).to include(indexed_user.username)
    end

    it 'filters by admin ip search' do
      matching = create(:user, username: 'IpMatch', lastip: '10.20.30.40')
      create(:user, username: 'IpMiss', lastip: '10.20.30.41')
      login_as(admin)

      get '/users', params: { search: 'ip:10.20.30.40' }

      expect(response).to have_http_status(:ok)
      expect(response.body).to include(matching.username)
      expect(response.body).not_to include('IpMiss')
    end

    it 'falls back to the normal search branch for non-ip admin searches' do
      searchable = create(:user, username: 'SearchVisible')
      login_as(admin)

      get '/users', params: { search: searchable.username }

      expect(response).to have_http_status(:ok)
      expect(response.body).to include(searchable.username)
    end

    it 'uses the lately filter when requested' do
      recent_user = create(:user, username: 'RecentUser', lastvisit: 1.day.ago)
      stale_user = create(:user, username: 'StaleUser', lastvisit: 6.months.ago)

      get '/users', params: { filter: 'lately' }

      expect(response).to have_http_status(:ok)
      expect(response.body).to include(recent_user.username)
      expect(response.body).not_to include(stale_user.username)
    end

    it 'does not allow guests to use the admin ip filter branch' do
      create(:user, username: 'PublicIpMatch', lastip: '10.10.10.10')
      create(:user, username: 'PublicIpMiss', lastip: '10.10.10.11')

      get '/users', params: { search: 'ip:10.10.10.10' }

      expect(response).to have_http_status(:ok)
      expect(response.body).not_to include('PublicIpMatch')
      expect(response.body).not_to include('PublicIpMiss')
    end
  end

  describe 'GET /users/:id' do
    it 'returns javascript successfully for a known page tab' do
      get "/users/#{user.id}",
          params: { page: 'movies' },
          headers: { 'HTTP_X_REQUESTED_WITH' => 'XMLHttpRequest', 'ACCEPT' => 'text/javascript' }

      expect(response).to have_http_status(:ok)
    end

    it 'returns javascript successfully for an unknown page tab' do
      get "/users/#{user.id}",
          params: { page: 'not-a-real-page' },
          headers: { 'HTTP_X_REQUESTED_WITH' => 'XMLHttpRequest', 'ACCEPT' => 'text/javascript' }

      expect(response).to have_http_status(:ok)
    end
  end

  describe 'GET /users/new' do
    it 'redirects a logged-in non-admin to their edit page' do
      login_as(user)

      get '/users/new'

      expect(response).to redirect_to(edit_user_path(user))
      expect(flash[:notice]).to eq('You are already logged in.')
    end

    it 'allows an admin to open the new-user form' do
      login_as(admin)

      get '/users/new'

      expect(response).to have_http_status(:ok)
      expect(response).to render_template(:new)
    end
  end

  describe 'GET /users/:id/edit' do
    it 'allows users to edit their own profile' do
      login_as(user)

      get "/users/#{user.id}/edit"

      expect(response).to have_http_status(:ok)
      expect(response).to render_template(:edit)
    end

    it 'returns 403 when another non-admin requests the edit form' do
      other_user = create(:user)
      login_as(other_user)

      get "/users/#{user.id}/edit"

      expect(response).to have_http_status(:forbidden)
    end
  end

  describe 'GET /users/:id/agenda' do
    it 'allows the user to view their own agenda' do
      login_as(user)

      get "/users/#{user.id}/agenda"

      expect(response).to have_http_status(:ok)
      expect(response).to render_template(:agenda)
    end

    it 'allows admins to view another users agenda' do
      login_as(admin)

      get "/users/#{user.id}/agenda"

      expect(response).to have_http_status(:ok)
      expect(response).to render_template(:agenda)
    end

    it 'returns 403 when another non-admin user requests it' do
      other_user = create(:user)
      login_as(other_user)

      get "/users/#{user.id}/agenda"

      expect(response).to have_http_status(:forbidden)
    end

    it 'returns 403 for guests' do
      get "/users/#{user.id}/agenda"

      expect(response).to have_http_status(:forbidden)
    end

    it 'renders team-join form tags (not just inner fields)' do
      create(:team)
      login_as(user)

      get "/users/#{user.id}/agenda"

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('action="/teamers"')
      expect(response.body).to include('name="teamer[user_id]"')
      expect(response.body).to include('Join an existing team')
    end

    it 'keeps movie upload link on agenda using the hardcoded movies directory id constant' do
      login_as(user)

      get "/users/#{user.id}/agenda"

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("/data_files/new?id=#{Directory::MOVIES}")
    end
  end

  describe 'GET /users/:id/history' do
    it 'allows admins' do
      login_as(admin)

      get "/users/#{user.id}/history"

      expect(response).to have_http_status(:ok)
      expect(response).to render_template(:history)
    end

    it 'returns 403 for non-admins' do
      login_as(user)

      get "/users/#{user.id}/history"

      expect(response).to have_http_status(:forbidden)
    end
  end

  describe 'POST /users' do
    let(:valid_params) { attributes_for(:user) }

    it 'redirects a logged-in non-admin instead of creating a second account' do
      login_as(user)

      expect do
        post '/users', params: { user: valid_params }
      end.not_to change(User, :count)

      expect(response).to redirect_to(edit_user_path(user))
      expect(flash[:notice]).to eq('You are already logged in.')
    end

    it 'creates a user for an admin request' do
      login_as(admin)

      expect do
        post '/users', params: { user: valid_params }
      end.to change(User, :count).by(1)

      expect(response).to redirect_to(user_path(User.order(:id).last))
    end

    it 're-renders the form when the payload is invalid' do
      login_as(admin)

      expect do
        post '/users', params: { user: valid_params.merge(email: 'not-an-email') }
      end.not_to change(User, :count)

      expect(response).to have_http_status(:ok)
      expect(response).to render_template(:new)
    end
  end

  describe 'PATCH /users/:id' do
    it 'lets a non-admin update their own profile without changing username' do
      login_as(user)

      patch "/users/#{user.id}", params: { user: { username: 'RenamedUser', firstname: 'Updated' } }

      expect(response).to redirect_to(user_path(user))
      expect(user.reload.firstname).to eq('Updated')
      expect(user.username).not_to eq('RenamedUser')
    end

    it 're-renders edit on validation failure' do
      login_as(admin)

      patch "/users/#{user.id}", params: { user: { email: 'not-an-email' } }

      expect(response).to have_http_status(:ok)
      expect(response).to render_template(:edit)
      expect(flash[:error]).to be_present
    end

    it 'returns 403 when another non-admin tries to update the user' do
      other_user = create(:user)
      login_as(other_user)

      patch "/users/#{user.id}", params: { user: { firstname: 'Nope' } }

      expect(response).to have_http_status(:forbidden)
      expect(user.reload.firstname).not_to eq('Nope')
    end
  end

  describe 'POST /users/login' do
    it 'sets the session on success' do
      post '/users/login', params: { login: { username: user.username, password: user.raw_password } }

      expect(session[:user]).to eq(user.id)
      expect(response).to redirect_to('/')
    end

    it 'keeps the session empty and sets a flash error on failure' do
      post '/users/login', params: { login: { username: user.username, password: 'wrong-password' } }

      expect(session[:user]).to be_nil
      expect(response).to redirect_to('/')
      expect(flash[:error]).to be_present
    end
  end

  describe 'POST /users/logout' do
    it 'clears the current session' do
      login_as(user)

      post '/users/logout'

      expect(session[:user]).to be_nil
      expect(response).to redirect_to('/')
      expect(flash[:notice]).to be_present
    end
  end

  describe 'DELETE /users/:id' do
    it 'allows admins to destroy users' do
      user
      login_as(admin)

      expect do
        delete "/users/#{user.id}"
      end.to change(User, :count).by(-1)

      expect(response).to redirect_to(users_path)
    end

    it 'returns 403 for non-admins' do
      other_user = create(:user)
      user
      login_as(other_user)

      expect do
        delete "/users/#{user.id}"
      end.not_to change(User, :count)

      expect(response).to have_http_status(:forbidden)
    end
  end

  describe 'POST /users/forgot' do
    it 'sets a success flash when the matching user can be reset' do
      allow_any_instance_of(User).to receive(:send_new_password).and_return(true)

      post '/users/forgot', params: { username: user.username, email: user.email }

      expect(response).to have_http_status(:ok)
      expect(flash[:notice]).to be_present
    end

    it 'sets an error flash when the user lookup fails' do
      post '/users/forgot', params: { username: user.username, email: 'wrong@example.com' }

      expect(response).to have_http_status(:ok)
      expect(flash[:error]).to be_present
    end
  end
end
