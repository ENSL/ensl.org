# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'SessionsController', type: :request do
  let(:user) { create(:user) }

  def login_as(account)
    post '/sessions/login', params: { login: { username: account.username, password: account.raw_password } }
  end

  describe 'POST /sessions/login' do
    it 'sets the session on success' do
      post '/sessions/login', params: { login: { username: user.username, password: user.raw_password } }

      expect(session[:user]).to eq(user.id)
      expect(response).to redirect_to('/')
    end

    it 'keeps the session empty and sets a flash error on failure' do
      post '/sessions/login', params: { login: { username: user.username, password: 'wrong-password' } }

      expect(session[:user]).to be_nil
      expect(response).to redirect_to('/')
      expect(flash[:error]).to be_present
    end

    it 'requires OTP after password when passkeys are enabled' do
      PasskeyCredential.create!(
        user: user,
        external_id: 'test-external-id',
        public_key: 'test-public-key',
        sign_count: 0
      )

      ActionMailer::Base.deliveries.clear

      post '/sessions/login', params: { login: { username: user.username, password: user.raw_password } }

      expect(session[:user]).to be_nil
      expect(session[:pending_login_otp]).to be_present
      expect(ActionMailer::Base.deliveries.size).to eq(1)
      expect(flash[:notice]).to eq(I18n.t('sessions.otp.sent'))
    end

    it 'logs in after valid OTP verification' do
      PasskeyCredential.create!(
        user: user,
        external_id: 'test-external-id-2',
        public_key: 'test-public-key',
        sign_count: 0
      )

      ActionMailer::Base.deliveries.clear

      post '/sessions/login', params: { login: { username: user.username, password: user.raw_password } }

      body = delivered_email_body(ActionMailer::Base.deliveries.last)
      otp = body[/\b\d{6}\b/]
      expect(otp).to be_present

      post '/sessions/login', params: { login_otp: { code: otp } }

      expect(session[:user]).to eq(user.id)
      expect(session[:pending_login_otp]).to be_nil
    end
  end

  describe 'POST /sessions/logout' do
    it 'clears the current session' do
      login_as(user)

      post '/sessions/logout'

      expect(session[:user]).to be_nil
      expect(response).to redirect_to('/')
      expect(flash[:notice]).to be_present
    end
  end

  describe 'POST /sessions/forgot' do
    it 'sets a success flash when the matching user can be reset' do
      allow_any_instance_of(User).to receive(:send_new_password).and_return(true)

      post '/sessions/forgot', params: { username: user.username, email: user.email }

      expect(response).to have_http_status(:ok)
      expect(flash[:notice]).to be_present
    end

    it 'sets an error flash when the user lookup fails' do
      post '/sessions/forgot', params: { username: user.username, email: 'wrong@example.com' }

      expect(response).to have_http_status(:ok)
      expect(flash[:error]).to be_present
    end
  end

  describe 'POST /users/login' do
    it 'keeps the legacy compatibility route working' do
      post '/users/login', params: { login: { username: user.username, password: user.raw_password } }

      expect(session[:user]).to eq(user.id)
    end
  end

  describe 'POST /users/logout' do
    it 'keeps the legacy compatibility route working' do
      login_as(user)

      post '/users/logout'

      expect(session[:user]).to be_nil
      expect(response).to redirect_to('/')
    end
  end

  describe 'POST /users/forgot' do
    it 'keeps the legacy compatibility route working' do
      allow_any_instance_of(User).to receive(:send_new_password).and_return(true)

      post '/users/forgot', params: { username: user.username, email: user.email }

      expect(response).to have_http_status(:ok)
      expect(flash[:notice]).to be_present
    end
  end
end
