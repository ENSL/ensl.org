# frozen_string_literal: true

require 'rails_helper'

RSpec.describe MatchesController, type: :controller do
  let(:admin) { create(:user, :admin) }
  let(:user) { create(:user) }
  let(:contest) { create(:contest) }
  let(:contester1) { create(:contester, contest: contest) }
  let(:contester2) { create(:contester, contest: contest) }
  let(:match_record) { create(:match, contest: contest, contester1: contester1, contester2: contester2) }

  before do
    routes.draw do
      resources :matches do
        member do
          get :show
          post :hltv
        end
      end
    end
  end

  after do
    Rails.application.reload_routes!
  end

  describe '#hltv' do
    before do
      allow_any_instance_of(Match).to receive(:can_update?).and_return(true)
    end

    it 'records through hltv send requests' do
      session[:user] = admin.id
      allow_any_instance_of(Match).to receive(:hltv_record)

      post :hltv, params: { id: match_record.id, commit: I18n.t(:hltv_send), addr: '1.2.3.4', pwd: 'pw' }

      expect(response).to redirect_to(action: 'show')
      expect(flash[:notice]).to eq(I18n.t(:hltv_recording))
    end

    it 'moves hltv demos without waiting by default' do
      session[:user] = admin.id
      allow_any_instance_of(Match).to receive(:hltv_move)
      expect(controller).not_to receive(:sleep)

      post :hltv, params: { id: match_record.id, commit: I18n.t(:hltv_move), addr: '1.2.3.4', pwd: 'pw', wait: '0' }

      expect(response).to redirect_to(action: 'show')
      expect(flash[:notice]).to eq(I18n.t(:hltv_moved))
    end

    it 'waits before moving hltv demos when requested' do
      session[:user] = admin.id
      allow_any_instance_of(Match).to receive(:hltv_move)
      expect(controller).to receive(:sleep).with(90)

      post :hltv, params: { id: match_record.id, commit: I18n.t(:hltv_move), addr: '1.2.3.4', pwd: 'pw', wait: '1' }

      expect(response).to redirect_to(action: 'show')
      expect(flash[:notice]).to eq(I18n.t(:hltv_moved))
    end

    it 'waits before stopping hltv demos when requested' do
      session[:user] = admin.id
      allow_any_instance_of(Match).to receive(:hltv_stop)
      expect(controller).to receive(:sleep).with(90)

      post :hltv, params: { id: match_record.id, commit: I18n.t(:hltv_stop), wait: '1' }

      expect(response).to redirect_to(action: 'show')
      expect(flash[:notice]).to eq(I18n.t(:hltv_stopped))
    end

    it 'returns 403 for unauthorized users' do
      session[:user] = user.id
      allow_any_instance_of(Match).to receive(:can_update?).and_return(false)

      post :hltv, params: { id: match_record.id, commit: I18n.t(:hltv_send) }

      expect(response).to have_http_status(:forbidden)
    end
  end
end
