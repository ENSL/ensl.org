# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'WeeksController', type: :request do
  let(:admin) { create(:user, :admin) }
  let(:user) { create(:user) }
  let(:contest) { create(:contest) }
  let(:week) { create(:week, contest: contest) }

  describe 'GET /weeks/new' do
    it 'allows admins' do
      login_as(admin)

      get '/weeks/new', params: { id: contest.id }

      expect(response).to have_http_status(:ok)
      expect(response).to render_template(:new)
    end

    it 'returns 403 for non-admins' do
      login_as(user)

      get '/weeks/new', params: { id: contest.id }

      expect(response).to have_http_status(:forbidden)
    end
  end

  describe 'GET /weeks/:id/edit' do
    it 'allows admins' do
      login_as(admin)

      get "/weeks/#{week.id}/edit"

      expect(response).to have_http_status(:ok)
      expect(response).to render_template(:edit)
    end

    it 'returns 403 for non-admins' do
      login_as(user)

      get "/weeks/#{week.id}/edit"

      expect(response).to have_http_status(:forbidden)
    end
  end

  describe 'POST /weeks' do
    let(:valid_params) do
      {
        week: {
          name: 'Playoff Week',
          start_date: Date.current,
          contest_id: contest.id,
          map1_id: create(:map).id,
          map2_id: create(:map).id
        }
      }
    end

    it 'creates a week for admins' do
      login_as(admin)

      expect do
        post '/weeks', params: valid_params
      end.to change(Week, :count).by(1)

      expect(response).to redirect_to(edit_contest_path(contest, contest: 'weeks'))
    end

    it 're-renders new for invalid data' do
      login_as(admin)

      expect do
        post '/weeks', params: { week: valid_params[:week].merge(name: '') }
      end.not_to change(Week, :count)

      expect(response).to have_http_status(:unprocessable_entity)
      expect(response).to render_template(:new)
      expect(flash.now[:error]).to be_present
    end

    it 'returns 403 for non-admins' do
      login_as(user)

      expect do
        post '/weeks', params: valid_params
      end.not_to change(Week, :count)

      expect(response).to have_http_status(:forbidden)
    end
  end

  describe 'PATCH /weeks/:id' do
    it 'updates the week for admins' do
      login_as(admin)

      patch "/weeks/#{week.id}",
            params: { week: { name: 'Updated Week', contest_id: contest.id, map1_id: week.map1_id,
                              map2_id: week.map2_id } }

      expect(response).to redirect_to(edit_contest_path(contest, contest: 'weeks'))
      expect(week.reload.name).to eq('Updated Week')
    end

    it 're-renders edit for invalid data' do
      login_as(admin)

      patch "/weeks/#{week.id}",
            params: { week: { name: '', contest_id: contest.id, map1_id: week.map1_id, map2_id: week.map2_id } }

      expect(response).to have_http_status(:unprocessable_entity)
      expect(response).to render_template(:edit)
      expect(week.reload.name).not_to eq('')
      expect(flash.now[:error]).to be_present
    end

    it 'returns 403 for non-admins' do
      login_as(user)

      patch "/weeks/#{week.id}", params: { week: { name: 'Blocked' } }

      expect(response).to have_http_status(:forbidden)
      expect(week.reload.name).not_to eq('Blocked')
    end
  end

  describe 'DELETE /weeks/:id' do
    it 'destroys a week for admins' do
      target_week = create(:week, contest: contest)
      login_as(admin)

      expect do
        delete "/weeks/#{target_week.id}"
      end.to change(Week, :count).by(-1)

      expect(response).to redirect_to(edit_contest_path(contest, contest: 'weeks'))
    end

    it 'returns 403 for non-admins' do
      target_week = week
      login_as(user)

      expect do
        delete "/weeks/#{target_week.id}"
      end.not_to change(Week, :count)

      expect(response).to have_http_status(:forbidden)
    end
  end
end
