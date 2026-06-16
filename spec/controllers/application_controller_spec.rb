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
  end

  before do
    routes.draw do
      get 'index' => 'anonymous#index'
      get 'remember' => 'anonymous#remember'
      get 'send_back' => 'anonymous#send_back'
      get 'send_redirect_back' => 'anonymous#send_redirect_back'
      get 'send_safe' => 'anonymous#send_safe'
      get 'send_safe_url' => 'anonymous#send_safe_url'
    end
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
  end

  describe '#return_back' do
    it 'falls back to root when no return_to is stored' do
      get :send_back

      expect(response).to redirect_to('/')
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
  end
end
