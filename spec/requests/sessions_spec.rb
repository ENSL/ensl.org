# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'SessionsController', type: :request do
  let(:user) { create(:user) }

  def login_as(account)
    post '/users/login', params: { login: { username: account.username, password: account.raw_password } }
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
