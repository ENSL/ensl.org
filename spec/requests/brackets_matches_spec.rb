# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Brackets and Matches controllers', type: :request do
  let(:admin) { create(:user, :admin) }
  let(:user) { create(:user) }

  def login_as(account)
    post '/sessions/login', params: { login: { username: account.username, password: account.raw_password } }
    follow_redirect! if response.redirect?
    expect(flash[:notice]).to be_present
  end

  describe 'BracketsController' do
    let(:contest) { create(:contest, :bracket_ready) }
    let(:bracket) { create(:bracket, contest: contest, slots: 4) }

    it 'renders the show page' do
      get "/brackets/#{bracket.id}"

      expect(response).to have_http_status(:ok)
    end

    it 'returns 403 when a guest tries to edit' do
      get "/brackets/#{bracket.id}/edit"

      expect(response).to have_http_status(:forbidden)
    end

    it 'renders the edit page for admins' do
      login_as(admin)

      get "/brackets/#{bracket.id}/edit"

      expect(response).to have_http_status(:ok)
    end

    it 'creates a bracket for admins' do
      login_as(admin)

      expect do
        post '/brackets', params: {
          bracket: {
            contest_id: contest.id,
            name: 'Created bracket',
            slots: 4
          }
        }
      end.to change(Bracket, :count).by(1)

      expect(response).to redirect_to(edit_contest_path(contest))
      expect(flash[:notice]).to be_present
    end

    it 'redirects back to the contest with an error when creation is invalid' do
      login_as(admin)

      expect do
        post '/brackets', params: {
          bracket: {
            contest_id: contest.id,
            name: '',
            slots: 0
          }
        }
      end.not_to change(Bracket, :count)

      expect(response).to redirect_to(edit_contest_path(contest))
      expect(flash[:error]).to be_present
    end

    it 'returns 422 when an update is invalid' do
      login_as(admin)

      patch "/brackets/#{bracket.id}", params: {
        bracket: {
          contest_id: contest.id,
          name: '',
          slots: bracket.slots
        }
      }

      expect(response).to have_http_status(:unprocessable_content)
    end

    it 'updates bracket cells and custom text' do
      login_as(admin)

      patch "/brackets/#{bracket.id}", params: {
        bracket: {
          contest_id: contest.id,
          name: 'Updated Bracket',
          slots: bracket.slots
        },
        cell: {
          '1' => { '0' => 'disabled' }
        },
        cell_custom: {
          '3' => { '0' => 'Winner TBD' }
        }
      }

      expect(response).to redirect_to(edit_bracket_path(bracket))
      expect(bracket.reload.name).to eq('Updated Bracket')
      expect(bracket.bracketers.pos(1, 0).first.disabled).to be(true)
      expect(bracket.bracketers.pos(3, 0).first.custom_text).to eq('Winner TBD')
    end

    it 'returns 403 when a guest tries to update' do
      patch "/brackets/#{bracket.id}", params: {
        bracket: {
          contest_id: contest.id,
          name: 'Blocked',
          slots: bracket.slots
        }
      }

      expect(response).to have_http_status(:forbidden)
    end

    it 'destroys a bracket as admin' do
      login_as(admin)

      delete "/brackets/#{bracket.id}"

      expect(response).to redirect_to(edit_contest_path(contest))
      expect(Bracket.exists?(bracket.id)).to be(false)
    end

    it 'returns 403 when a guest tries to destroy a bracket' do
      delete "/brackets/#{bracket.id}"

      expect(response).to have_http_status(:forbidden)
      expect(Bracket.exists?(bracket.id)).to be(true)
    end
  end

  describe 'MatchesController' do
    let(:contest) { create(:contest) }
    let(:contester1) { create(:contester, contest: contest) }
    let(:contester2) { create(:contester, contest: contest) }
    let(:match_record) { create(:match, contest: contest, contester1: contester1, contester2: contester2) }

    it 'renders the show page for guests' do
      get "/matches/#{match_record.id}"

      expect(response).to have_http_status(:ok)
    end

    it 'renders the show page for signed in users' do
      create(:prediction, match: match_record, user: user, score1: 3, score2: 2)
      login_as(user)

      get "/matches/#{match_record.id}"

      expect(response).to have_http_status(:ok)
    end

    it 'renders prediction form tags for logged-in users when predictions are allowed' do
      login_as(user)
      match_record.update!(match_time: 2.hours.from_now, score1: nil, score2: nil)

      get "/matches/#{match_record.id}"

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('action="/predictions"')
      expect(response.body).to include('name="prediction[score1]"')
      expect(response.body).to include('name="prediction[score2]"')
    end

    it 'renders referee signup form tags for referees when no referee is assigned' do
      ref_user = create(:user, :ref)
      login_as(ref_user)
      match_record.update!(match_time: 2.hours.from_now, referee: nil)

      get "/matches/#{match_record.id}"

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('Signup as referee')
      expect(response.body).to include("action=\"/matches/#{match_record.id}\"")
      expect(response.body).to include('name="match[referee_id]"')
    end

    it 'renders the new form for admins' do
      login_as(admin)

      get '/matches/new', params: { id: contest.id }

      expect(response).to have_http_status(:ok)
      expect(response).to render_template(:new)
    end

    it 'returns 403 for regular users on new' do
      login_as(user)

      get '/matches/new', params: { id: contest.id }

      expect(response).to have_http_status(:forbidden)
    end

    it 'renders the edit form for admins' do
      login_as(admin)

      get "/matches/#{match_record.id}/edit"

      expect(response).to have_http_status(:ok)
      expect(response).to render_template(:edit)
    end

    it 'returns 403 for regular users on edit' do
      login_as(user)

      get "/matches/#{match_record.id}/edit"

      expect(response).to have_http_status(:forbidden)
    end

    it 'renders the referee page for admins' do
      login_as(admin)

      get "/matches/#{match_record.id}/ref"

      expect(response).to have_http_status(:ok)
      expect(response).to render_template(:ref)
    end

    it 'returns 403 for regular users on the referee page' do
      login_as(user)

      get "/matches/#{match_record.id}/ref"

      expect(response).to have_http_status(:forbidden)
    end

    it 'creates a valid match for admins' do
      login_as(admin)

      expect do
        post '/matches', params: {
          match: {
            contest_id: contest.id,
            contester1_id: contester1.id,
            contester2_id: contester2.id,
            match_time: 1.day.from_now
          }
        }
      end.to change(Match, :count).by(1)

      expect(response).to redirect_to(edit_contest_path(contest, contest: 'matches'))
    end

    it 'returns 422 when match creation is invalid' do
      login_as(admin)

      post '/matches', params: {
        match: {
          contest_id: contest.id,
          contester1_id: nil,
          contester2_id: contester2.id
        }
      }

      expect(response).to have_http_status(:unprocessable_content)
    end

    it 'redirects back to the admin page after a valid update from the admin listing' do
      login_as(admin)

      patch "/matches/#{match_record.id}",
            params: { match: { report: 'Updated from request spec' } },
            headers: { 'HTTP_REFERER' => 'http://www.example.com/matches/admin' }

      expect(response).to redirect_to('/matches/admin')
      expect(match_record.reload.report).to eq('Updated from request spec')
    end

    it 'redirects to the match show page after a normal valid update' do
      login_as(admin)

      patch "/matches/#{match_record.id}", params: {
        match: { report: 'Updated normally' }
      }

      expect(response).to redirect_to(match_path(match_record))
      expect(match_record.reload.report).to eq('Updated normally')
    end

    it 'updates through the xml response branch' do
      login_as(admin)

      patch "/matches/#{match_record.id}.xml", params: {
        match: { report: 'Updated via xml' }
      }

      expect(response).to have_http_status(:ok)
      expect(match_record.reload.report).to eq('Updated via xml')
    end

    it 'normalizes matcher attributes before update' do
      replacement_user = create(:user)
      login_as(admin)

      patch "/matches/#{match_record.id}", params: {
        match: {
          report: 'Updated with lineup attrs',
          matchers_attributes: {
            '0' => { 'user_id' => '', '_destroy' => 'keep' },
            '1' => { 'user_id' => replacement_user.username, '_destroy' => 'keep' }
          }
        }
      }

      expect(response).to redirect_to(match_path(match_record))
      expect(match_record.reload.report).to eq('Updated with lineup attrs')
    end

    it 'renders the referee form when an invalid update comes from the ref page' do
      login_as(admin)

      patch "/matches/#{match_record.id}",
            params: { match: { report: 'x' * 64_001 } },
            headers: { 'HTTP_REFERER' => "http://www.example.com/matches/#{match_record.id}/ref" }

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.body).to include('Referee Admin')
    end

    it 'renders the edit form when an invalid update does not come from the ref page' do
      login_as(admin)

      patch "/matches/#{match_record.id}", params: {
        match: { report: 'x' * 64_001 }
      }

      expect(response).to have_http_status(:unprocessable_content)
      expect(response).to render_template(:edit)
    end

    it 'destroys a match as admin' do
      login_as(admin)

      delete "/matches/#{match_record.id}"

      expect(response).to redirect_to(edit_contest_path(contest, anchor: 'matches'))
      expect(Match.exists?(match_record.id)).to be(false)
    end

    it 'returns 403 when a non-admin tries to destroy a match' do
      login_as(user)

      delete "/matches/#{match_record.id}"

      expect(response).to have_http_status(:forbidden)
      expect(Match.exists?(match_record.id)).to be(true)
    end
  end
end
