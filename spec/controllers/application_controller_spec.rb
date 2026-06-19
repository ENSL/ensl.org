# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ApplicationController, type: :controller do
  controller(ApplicationController) do
    def index
      render plain: cuser&.username || 'guest'
    end

    def remember
      return_here
      render plain: 'ok'
    end

    def send_back
      return_back
    end

    def send_redirect_back
      redirect_to_back
    end

    def send_safe
      safe_redirect_to(params[:target])
    end

    def send_safe_url
      render plain: safe_url_for(params[:target])
    end

    def blow_up_not_found
      raise ActiveRecord::RecordNotFound
    end

    def require_registration
      raise Exceptions::UserRegistrationReq
    end

    def cross_origin
      raise ActionController::InvalidCrossOriginRequest
    end

    def stale
      raise ActiveRecord::StaleObjectError.new(User.new, 'update')
    end
  end

  before do
    routes.draw do
      get 'index' => 'anonymous#index'
      get 'remember' => 'anonymous#remember'
      get 'send_back' => 'anonymous#send_back'
      get 'send_redirect_back' => 'anonymous#send_redirect_back'
      get 'send_safe' => 'anonymous#send_safe'
      get 'send_safe_url' => 'anonymous#send_safe_url'
      get 'blow_up_not_found' => 'anonymous#blow_up_not_found'
      get 'require_registration' => 'anonymous#require_registration'
      get 'cross_origin' => 'anonymous#cross_origin'
      get 'stale' => 'anonymous#stale'
    end
  end

  after do
    Rails.application.reload_routes!
  end

  describe '#cuser' do
    it 'returns the logged in user from the session' do
      user = create(:user)
      session[:user] = user.id

      get :index

      expect(response.body).to eq(user.username)
    end

    it 'returns guest when the session user cannot be found' do
      session[:user] = -1

      get :index

      expect(response.body).to eq('guest')
    end
  end

  describe '#return_here' do
    it 'stores the current url for html get requests' do
      get :remember

      expect(session[:return_to]).to eq('http://test.host/remember')
    end

    it 'does not store the url for non-html requests' do
      get :remember, format: :json

      expect(session[:return_to]).to be_nil
    end
  end

  describe '#return_back' do
    it 'falls back to root when no return_to is stored' do
      get :send_back

      expect(response).to redirect_to('/')
    end

    it 'redirects to the stored return_to path and clears it' do
      session[:return_to] = 'http://test.host/users?search=abc'

      get :send_back

      expect(response).to redirect_to('/users?search=abc')
      expect(session[:return_to]).to be_nil
    end
  end

  describe '#redirect_to_back' do
    it 'redirects to the referer when present' do
      request.env['HTTP_REFERER'] = '/index'

      get :send_redirect_back

      expect(response).to redirect_to('/index')
    end

    it 'falls back to root without a referer' do
      get :send_redirect_back

      expect(response).to redirect_to('/')
    end
  end

  describe '#safe_redirect_to' do
    it 'allows same-host absolute urls' do
      get :send_safe, params: { target: 'http://test.host/users?search=abc' }

      expect(response).to redirect_to('/users?search=abc')
    end

    it 'rejects external urls' do
      get :send_safe, params: { target: 'https://evil.test/forums' }

      expect(response).to redirect_to('/')
    end

    it 'rejects error pages' do
      get :send_safe, params: { target: '/404' }

      expect(response).to redirect_to('/')
    end

    it 'rejects unknown paths' do
      get :send_safe, params: { target: '/missing-route' }

      expect(response).to redirect_to('/')
    end

    it 'rejects blank targets' do
      get :send_safe, params: { target: '' }

      expect(response).to redirect_to('/')
    end

    it 'rejects malformed urls' do
      get :send_safe, params: { target: 'http://[broken' }

      expect(response).to redirect_to('/')
    end
  end

  describe '#safe_url_for' do
    it 'allows relative paths' do
      get :send_safe_url, params: { target: '/index?page=2' }

      expect(response.body).to eq('/index?page=2')
    end

    it 'allows http urls' do
      get :send_safe_url, params: { target: 'https://ensl.example/forums' }

      expect(response.body).to eq('https://ensl.example/forums')
    end

    it 'rejects unsafe schemes' do
      get :send_safe_url, params: { target: 'javascript:alert(1)' }

      expect(response.body).to eq('#')
    end

    it 'rejects malformed urls' do
      get :send_safe_url, params: { target: 'http://[broken' }

      expect(response.body).to eq('#')
    end

    it 'rejects blank urls' do
      get :send_safe_url, params: { target: '' }

      expect(response.body).to eq('#')
    end
  end

  describe 'rescue handlers' do
    it 'renders plain forbidden text for registration-required errors' do
      get :require_registration

      expect(response).to have_http_status(:forbidden)
      expect(response.body).to include(I18n.t(:user_registration_required))
    end

    it 'returns 404 without rendering html for json record-not-found requests' do
      get :blow_up_not_found, format: :json

      expect(response).to have_http_status(:not_found)
      expect(response.body).to be_blank
    end

    it 'returns 406 for cross-origin javascript requests' do
      request.headers['ACCEPT'] = 'text/javascript'

      get :cross_origin, format: :js

      expect(response).to have_http_status(:not_acceptable)
    end

    it 'redirects back with a stale-object flash' do
      request.env['HTTP_REFERER'] = '/index'

      get :stale

      expect(response).to redirect_to('/index')
      expect(flash[:error]).to eq(I18n.t(:application_stale))
    end
  end

  describe 'before_action update_user' do
    it 'recreates a missing profile for signed-in users' do
      user = create(:user)
      user.profile&.destroy
      session[:user] = user.id

      get :index

      expect(response.body).to eq(user.username)
      expect(user.reload.profile).to be_present
      expect(flash[:notice]).to eq('Your profile has been removed and recreated.')
    end

    it 'logs site-banned users out during the request' do
      user = create(:user)
      create(:ban, :site, user: user)
      session[:user] = user.id

      get :index

      expect(response.body).to eq('guest')
      expect(session[:user]).to be_nil
    end
  end
end
