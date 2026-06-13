require 'rails_helper'

RSpec.describe 'Contests and Weeks controllers', type: :request do
  let(:admin) { create(:user, :admin) }
  let(:user) { create(:user) }

  def login_as(account)
    post '/users/login', params: { login: { username: account.username, password: account.raw_password } }
    follow_redirect! if response.redirect?
    expect(flash[:notice]).to be_present
  end

  describe 'GET /contests/scores' do
    it 'returns 403 for a non-ladder contest' do
      contest = create(:contest, :bracket)

      get '/contests/scores', params: { id: contest.id }

      expect(response).to have_http_status(:forbidden)
    end

    it 'returns 200 for a ladder contest and accepts round overrides' do
      contest = create(:contest)
      contester = create(:contester, contest: contest)

      get '/contests/scores', params: {
        id: contest.id,
        friendly: contester.id,
        rounds: { '0' => '1.1', '1' => '2.2', '2' => '3.3' },
        weight: '44'
      }

      expect(response).to have_http_status(:ok)
    end
  end

  describe 'GET /contests/:id/recalc' do
    it 'recalculates for an admin and redirects back' do
      contest = create(:contest)
      login_as(admin)

      get "/contests/#{contest.id}/recalc", headers: { 'HTTP_REFERER' => contest_path(contest) }

      expect(response).to redirect_to(contest_path(contest))
      expect(flash[:notice]).to eq('Contest points recalculated.')
    end

    it 'returns 403 for a non-admin' do
      contest = create(:contest)
      login_as(user)

      get "/contests/#{contest.id}/recalc"

      expect(response).to have_http_status(:forbidden)
    end
  end

  describe 'PATCH /contests/:id' do
    it 'returns 422 when a contest update is invalid' do
      contest = create(:contest)
      login_as(admin)

      patch "/contests/#{contest.id}", params: {
        type: 'contest',
        contest: { name: '' }
      }

      expect(response).to have_http_status(:unprocessable_content)
    end

    it 'returns 422 when a requested map does not exist' do
      contest = create(:contest)
      login_as(admin)

      patch "/contests/#{contest.id}", params: {
        type: 'map',
        map: '0'
      }

      expect(response).to have_http_status(:unprocessable_content)
    end

    it 'adds a map and redirects to the maps tab' do
      contest = create(:contest)
      map = create(:map)
      login_as(admin)

      patch "/contests/#{contest.id}", params: {
        type: 'map',
        map: map.id
      }

      expect(response).to redirect_to(edit_contest_path(contest, contest: 'maps'))
      expect(contest.reload.maps).to include(map)
    end

    it 'adds a team to the contest through the team branch' do
      contest = create(:contest)
      team = create(:team)
      login_as(admin)

      expect do
        patch "/contests/#{contest.id}", params: {
          type: 'team',
          team: team.id
        }
      end.to change(Contester, :count).by(1)

      expect(response).to have_http_status(:ok)
      expect(contest.reload.contesters.find_by(team: team)).to be_present
    end
  end

  describe 'DELETE /contests/del_map' do
    it 'removes an attached map and redirects to the maps tab' do
      contest = create(:contest, :with_maps, maps_count: 1)
      map = contest.maps.first
      login_as(admin)

      delete '/contests/del_map', params: { id: contest.id, id2: map.id }

      expect(response).to redirect_to(edit_contest_path(contest, contest: 'maps'))
      expect(contest.reload.maps).not_to include(map)
    end

    it 'handles a missing map id' do
      contest = create(:contest)
      login_as(admin)

      delete '/contests/del_map', params: { id: contest.id, id2: 0 }

      expect(response).to redirect_to(edit_contest_path(contest, contest: 'maps'))
      expect(flash[:error]).to be_present
    end
  end

  describe 'WeeksController' do
    let(:contest) { create(:contest) }
    let(:map1) { create(:map) }
    let(:map2) { create(:map) }

    before do
      contest.maps << [map1, map2]
    end

    it 'allows an admin to load the new form' do
      login_as(admin)

      get '/weeks/new', params: { id: contest.id }

      expect(response).to have_http_status(:ok)
    end

    it 'returns 403 when a non-admin tries to load the new form' do
      login_as(user)

      get '/weeks/new', params: { id: contest.id }

      expect(response).to have_http_status(:forbidden)
    end

    it 'creates a valid week and redirects to the contest weeks tab' do
      login_as(admin)

      expect do
        post '/weeks', params: {
          week: {
            contest_id: contest.id,
            name: 'Request Week',
            start_date: Date.today,
            map1_id: map1.id,
            map2_id: map2.id
          }
        }
      end.to change(Week, :count).by(1)

      expect(response).to redirect_to(edit_contest_path(contest, contest: 'weeks'))
    end

    it 'returns 422 when week creation is invalid' do
      login_as(admin)

      post '/weeks', params: {
        week: {
          contest_id: contest.id,
          name: '',
          start_date: Date.today,
          map1_id: map1.id,
          map2_id: nil
        }
      }

      expect(response).to have_http_status(:unprocessable_content)
    end

    it 'returns 422 when week update is invalid' do
      week = create(:week, contest: contest, map1: map1, map2: map2)
      login_as(admin)

      patch "/weeks/#{week.id}", params: {
        week: {
          name: '',
          map1_id: map1.id,
          map2_id: map2.id,
          contest_id: contest.id
        }
      }

      expect(response).to have_http_status(:unprocessable_content)
    end

    it 'destroys a week and redirects to the contest weeks tab' do
      week = create(:week, contest: contest, map1: map1, map2: map2)
      login_as(admin)

      expect do
        delete "/weeks/#{week.id}"
      end.to change(Week, :count).by(-1)

      expect(response).to redirect_to(edit_contest_path(contest, contest: 'weeks'))
    end
  end
end
