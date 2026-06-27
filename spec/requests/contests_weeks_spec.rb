# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Contests and Weeks controllers', type: :request do
  let(:admin) { create(:user, :admin) }
  let(:user) { create(:user) }

  def login_as(account)
    post '/users/login', params: { login: { username: account.username, password: account.raw_password } }
    follow_redirect! if response.redirect?
    expect(flash[:notice]).to be_present
  end

  describe 'GET /contests' do
    it 'renders current and inactive contests' do
      active_contest = create(:contest, name: 'Active Contest')
      inactive_contest = create(:contest, name: 'Inactive Contest', status: Contest::STATUS_CLOSED)

      get '/contests'

      expect(response).to have_http_status(:ok)
      expect(response.body).to include(active_contest.name)
      expect(response.body).to include(inactive_contest.name)
    end
  end

  describe 'GET /contests/current' do
    it 'renders current contests' do
      current_contest = create(:contest, name: 'Current Contest')

      get '/contests/current'

      expect(response).to have_http_status(:ok)
      expect(response.body).to include(current_contest.name)
    end
  end

  describe 'GET /contests/historical/:id' do
    it 'uses the NS1 branch' do
      ns1_contest = create(:contest, name: 'Season S1: Legacy Cup')
      contester1 = create(:contester, contest: ns1_contest)
      contester2 = create(:contester, contest: ns1_contest)
      create(:match, :scored, contest: ns1_contest, contester1: contester1, contester2: contester2)

      get '/contests/historical/NS1'

      expect(response).to have_http_status(:ok)
      expect(response.body).to include(ns1_contest.name)
    end

    it 'uses the default branch for other ids' do
      modern_contest = create(:contest, id: 200, name: 'Modern Contest')
      contester1 = create(:contester, contest: modern_contest)
      contester2 = create(:contester, contest: modern_contest)
      create(:match, :scored, contest: modern_contest, contester1: contester1, contester2: contester2)

      get '/contests/historical/NS2'

      expect(response).to have_http_status(:ok)
      expect(response.body).to include(modern_contest.name)
    end
  end

  describe 'GET /contests/:id' do
    it 'renders the show page' do
      contest = create(:contest)

      get "/contests/#{contest.id}"

      expect(response).to have_http_status(:ok)
    end
  end

  describe 'GET /contests/new' do
    it 'allows admins' do
      login_as(admin)

      get '/contests/new'

      expect(response).to have_http_status(:ok)
    end

    it 'returns 403 for non-admins' do
      login_as(user)

      get '/contests/new'

      expect(response).to have_http_status(:forbidden)
    end
  end

  describe 'GET /contests/:id/edit' do
    it 'allows admins' do
      contest = create(:contest)
      login_as(admin)

      get "/contests/#{contest.id}/edit"

      expect(response).to have_http_status(:ok)
    end

    it 'returns 403 for non-admins' do
      contest = create(:contest)
      login_as(user)

      get "/contests/#{contest.id}/edit"

      expect(response).to have_http_status(:forbidden)
    end
  end

  describe 'POST /contests' do
    it 'creates a contest for admins' do
      login_as(admin)

      expect do
        post '/contests', params: {
          contest: {
            name: 'Created Contest',
            start: Date.today,
            end: 1.week.from_now.to_date,
            contest_type: Contest::TYPE_LADDER,
            status: Contest::STATUS_OPEN,
            default_time: '12:00:00'
          }
        }
      end.to change(Contest, :count).by(1)

      expect(response).to redirect_to(contest_path(Contest.order(:id).last))
    end

    it 'returns 422 for invalid contests' do
      login_as(admin)

      expect do
        post '/contests', params: { contest: { name: '' } }
      end.not_to change(Contest, :count)

      expect(response).to have_http_status(:unprocessable_content)
      expect(response).to render_template(:new)
    end

    it 'returns 403 for non-admins' do
      login_as(user)

      expect do
        post '/contests', params: { contest: { name: 'Blocked Contest' } }
      end.not_to change(Contest, :count)

      expect(response).to have_http_status(:forbidden)
    end
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
    it 'updates contest attributes' do
      contest = create(:contest, name: 'Original Contest')
      login_as(admin)

      patch "/contests/#{contest.id}", params: {
        contest: { name: 'Updated Contest' }
      }

      expect(response).to redirect_to(contest_path(contest))
      expect(contest.reload.name).to eq('Updated Contest')
    end

    it 'returns 422 when a contest update is invalid' do
      contest = create(:contest)
      login_as(admin)

      patch "/contests/#{contest.id}", params: {
        contest: { name: '' }
      }

      expect(response).to have_http_status(:unprocessable_content)
    end

    it 'returns 403 for non-admins' do
      contest = create(:contest)
      login_as(user)

      patch "/contests/#{contest.id}", params: {
        contest: { name: 'Blocked Contest' }
      }

      expect(response).to have_http_status(:forbidden)
      expect(contest.reload.name).not_to eq('Blocked Contest')
    end
  end

  describe 'POST /contests/:contest_id/maps' do
    it 'adds a map and redirects to the maps tab' do
      contest = create(:contest)
      map = create(:map)
      login_as(admin)

      post "/contests/#{contest.id}/maps", params: { map: map.id }

      expect(response).to redirect_to(edit_contest_path(contest, contest: 'maps'))
      expect(contest.reload.maps).to include(map)
    end

    it 'redirects with an error when the requested map does not exist' do
      contest = create(:contest)
      login_as(admin)

      post "/contests/#{contest.id}/maps", params: { map: '0' }

      expect(response).to redirect_to(edit_contest_path(contest, contest: 'maps'))
      expect(flash[:error]).to be_present
    end

    it 'returns 403 for non-admins' do
      contest = create(:contest)
      map = create(:map)
      login_as(user)

      post "/contests/#{contest.id}/maps", params: { map: map.id }

      expect(response).to have_http_status(:forbidden)
      expect(contest.reload.maps).not_to include(map)
    end
  end

  describe 'DELETE /contests/:contest_id/maps/:id' do
    it 'removes an attached map and redirects to the maps tab' do
      contest = create(:contest, :with_maps, maps_count: 1)
      map = contest.maps.first
      login_as(admin)

      delete "/contests/#{contest.id}/maps/#{map.id}"

      expect(response).to redirect_to(edit_contest_path(contest, contest: 'maps'))
      expect(contest.reload.maps).not_to include(map)
    end

    it 'handles a missing map id' do
      contest = create(:contest)
      login_as(admin)

      delete "/contests/#{contest.id}/maps/0"

      expect(response).to redirect_to(edit_contest_path(contest, contest: 'maps'))
      expect(flash[:error]).to be_present
    end
  end

  describe 'GET /contests/:id/confirmedmatches' do
    it 'shows confirmed match proposals for a contest' do
      contest = create(:contest)
      contester1 = create(:contester, contest: contest)
      contester2 = create(:contester, contest: contest)
      match = create(:match, contest: contest, contester1: contester1, contester2: contester2)
      confirmed = create(:match_proposal, :confirmed, match: match, team: contester1.team)
      create(:match_proposal, :pending, match: match, team: contester2.team)

      get "/contests/#{contest.id}/confirmedmatches"

      expect(response).to have_http_status(:ok)
      expect(response.body).to include(confirmed.team.name)
    end
  end

  describe 'DELETE /contests/:id' do
    it 'destroys contests for admins' do
      contest = create(:contest)
      login_as(admin)

      expect do
        delete "/contests/#{contest.id}"
      end.to change(Contest, :count).by(-1)

      expect(response).to redirect_to(contests_path)
    end

    it 'returns 403 for non-admins' do
      contest = create(:contest)
      login_as(user)

      expect do
        delete "/contests/#{contest.id}"
      end.not_to change(Contest, :count)

      expect(response).to have_http_status(:forbidden)
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
