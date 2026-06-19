# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ContestersController, type: :controller do
  let(:admin) { create(:user, :admin) }
  let(:outsider) { create(:user) }

  before do
    routes.draw do
      resources :contests, only: [:edit]
      resources :contesters, only: %i[show create update destroy] do
        member do
          get :recover
        end
      end
    end
  end

  after do
    Rails.application.reload_routes!
  end

  describe '#show' do
    it 'returns 403 when the contester is missing required associations' do
      broken = double('Contester', contest: nil, team: nil)
      future_scope = double('FutureMatchScope', of_contester: [])
      finished_scope = double('FinishedMatchScope', of_contester: [])
      allow(Match).to receive_message_chain(:future, :unfinished, :ordered).and_return(future_scope)
      allow(Match).to receive_message_chain(:finished, :ordered).and_return(finished_scope)
      allow(Contester).to receive(:find).with('1').and_return(broken)

      get :show, params: { id: '1' }

      expect(response).to have_http_status(:forbidden)
    end
  end

  describe '#create' do
    it 'creates a non-ladder contester without assigning the ladder score branch' do
      session[:user] = admin.id
      contest = create(:contest, :bracket)
      team = create(:team)

      expect do
        post :create, params: { contester: { contest_id: contest.id, team_id: team.id } }
      end.to change(Contester, :count).by(1)

      created = Contester.order(:id).last
      expect(response).to redirect_to(edit_contest_path(contest, anchor: 'teams'))
      expect(created.score).to eq(0)
    end
  end

  describe '#update' do
    it 'returns 403 when a non-admin tries to update a contester' do
      contest = create(:contest)
      contester = create(:contester, contest: contest)
      session[:user] = outsider.id

      patch :update, params: {
        id: contester.id,
        contester: {
          contest_id: contest.id,
          team_id: contester.team_id,
          score: contester.score
        }
      }

      expect(response).to have_http_status(:forbidden)
    end

    it 'returns 500 when the new ladder rank exceeds the active contester count' do
      session[:user] = admin.id
      contesters = double('ContesterScope')
      contest = double('Contest', contest_type: Contest::TYPE_LADDER, contesters: contesters)
      contester = double('Contester', can_update?: true, contest: contest, score: 1)
      allow(contesters).to receive_message_chain(:active, :count).and_return(1)
      allow(Contester).to receive(:find).with('1').and_return(contester)

      patch :update, params: {
        id: '1',
        contester: {
          contest_id: '1',
          team_id: '1',
          score: 2
        }
      }

      expect(response).to have_http_status(:internal_server_error)
    end

    it 'does not rebalance ladder ranks when the rank stays the same' do
      session[:user] = admin.id
      contesters = double('ContesterScope')
      contest = double('Contest', contest_type: Contest::TYPE_LADDER, contesters: contesters)
      contester = double('Contester', can_update?: true, contest: contest, score: 1, contest_id: 1, update: true)
      allow(contesters).to receive_message_chain(:active, :count).and_return(2)
      allow(Contester).to receive(:find).with('1').and_return(contester)
      allow(Contester).to receive(:params).and_return(ActionController::Parameters.new(score: '1'))
      expect(contest).not_to receive(:update_ranks)

      patch :update, params: {
        id: '1',
        contester: {
          contest_id: '1',
          team_id: '1',
          score: 1
        }
      }

      expect(response).to redirect_to(edit_contest_path(1, anchor: 'teams'))
    end

    it 'rebalances ladder ranks when the rank changes' do
      session[:user] = admin.id
      contesters = double('ContesterScope')
      contest = double('Contest', contest_type: Contest::TYPE_LADDER, contesters: contesters)
      contester = double('Contester', can_update?: true, contest: contest, score: 1, contest_id: 1, update: true)
      allow(contesters).to receive_message_chain(:active, :count).and_return(2)
      allow(Contester).to receive(:find).with('1').and_return(contester)
      allow(Contester).to receive(:params).and_return(ActionController::Parameters.new(score: '2'))
      expect(contest).to receive(:update_ranks).with(contester, 1, 2)

      patch :update, params: {
        id: '1',
        contester: {
          contest_id: '1',
          team_id: '1',
          score: 2
        }
      }

      expect(response).to redirect_to(edit_contest_path(1, anchor: 'teams'))
    end
  end

  describe '#recover' do
    it 'allows admins to recover a contester' do
      session[:user] = admin.id
      contester = double('Contester', can_destroy?: true, contest_id: 1, recover: true)
      allow(Contester).to receive(:find).with('1').and_return(contester)

      get :recover, params: { id: '1' }

      expect(response).to redirect_to(edit_contest_path(1, anchor: 'teams'))
      expect(flash[:notice]).to eq(I18n.t(:contests_contester_recovered))
    end

    it 'returns 403 when the user cannot recover the contester' do
      contester = double('Contester', can_destroy?: false)
      allow(Contester).to receive(:find).with('1').and_return(contester)
      session[:user] = outsider.id

      get :recover, params: { id: '1' }

      expect(response).to have_http_status(:forbidden)
    end
  end
end
