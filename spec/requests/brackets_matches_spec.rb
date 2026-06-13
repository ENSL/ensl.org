require 'rails_helper'

RSpec.describe 'Brackets and Matches controllers', type: :request do
  let(:admin) { create(:user, :admin) }
  let(:user) { create(:user) }

  def login_as(account)
    post '/users/login', params: { login: { username: account.username, password: account.raw_password } }
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

    it 'destroys a bracket as admin' do
      login_as(admin)

      delete "/brackets/#{bracket.id}"

      expect(response).to redirect_to(edit_contest_path(contest))
      expect(Bracket.exists?(bracket.id)).to be(false)
    end
  end

  describe 'MatchesController' do
    let(:contest) { create(:contest) }
    let(:contester1) { create(:contester, contest: contest) }
    let(:contester2) { create(:contester, contest: contest) }
    let(:match_record) { create(:match, contest: contest, contester1: contester1, contester2: contester2) }

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

    it 'renders the referee form when an invalid update comes from the ref page' do
      login_as(admin)

      patch "/matches/#{match_record.id}",
            params: { match: { report: 'x' * 64_001 } },
            headers: { 'HTTP_REFERER' => "http://www.example.com/matches/#{match_record.id}/ref" }

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.body).to include('Referee Admin')
    end

    it 'destroys a match as admin' do
      login_as(admin)

      delete "/matches/#{match_record.id}"

      expect(response).to redirect_to(edit_contest_path(contest, anchor: 'matches'))
      expect(Match.exists?(match_record.id)).to be(false)
    end
  end
end
