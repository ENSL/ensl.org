require 'rails_helper'

RSpec.describe 'Contesters and Challenges controllers', type: :request do
  let(:admin) { create(:user, :admin) }

  def login_as(account)
    post '/users/login', params: { login: { username: account.username, password: account.raw_password } }
    follow_redirect! if response.redirect?
    expect(flash[:notice]).to be_present
  end

  describe 'ContestersController' do
    let(:contest) { create(:contest) }

    it 'assigns the next ladder score on create' do
      existing = create(:contester, contest: contest)
      team = create(:team)
      login_as(admin)

      expect do
        post '/contesters', params: {
          contester: {
            contest_id: contest.id,
            team_id: team.id
          }
        }
      end.to change(Contester, :count).by(1)

      created = Contester.order(:id).last
      expect(response).to redirect_to(edit_contest_path(contest, anchor: 'teams'))
      expect(created.score).to eq(existing.contest.contesters.active.count)
    end

    it 'returns 500 when a ladder rank update is invalid' do
      contester = create(:contester, contest: contest)
      login_as(admin)

      patch "/contesters/#{contester.id}", params: {
        contester: {
          contest_id: contest.id,
          team_id: contester.team_id,
          score: 0
        }
      }

      expect(response).to have_http_status(:internal_server_error)
      expect(response.body).to include(I18n.t(:rank_invalid))
    end

    it 'soft deletes a contester and redirects to the teams tab' do
      contester = create(:contester, contest: contest)
      login_as(admin)

      delete "/contesters/#{contester.id}"

      expect(response).to redirect_to(edit_contest_path(contest, anchor: 'teams'))
      expect(contester.reload.active).to be(false)
    end
  end

  describe 'ChallengesController' do
    let(:team1_leader) { create(:user_with_team, username: 'challenge_team1_leader') }
    let(:team2_leader) { create(:user_with_team, username: 'challenge_team2_leader') }
    let(:outsider) { create(:user) }
    let(:contest) { create(:contest) }
    let(:map) { create(:map) }
    let(:contester1) { create(:contester, contest: contest, team: team1_leader.team) }
    let(:contester2) { create(:contester, contest: contest, team: team2_leader.team) }

    before do
      contest.maps << map
    end

    it 'allows the challenging leader to load the new form' do
      contester1
      contester2
      login_as(team1_leader)

      get '/challenges/new', params: { id: contester2.id }

      expect(response).to have_http_status(:ok)
    end

    it 'returns 403 when a non-participant tries to load the new form' do
      contester1
      contester2
      login_as(outsider)

      get '/challenges/new', params: { id: contester2.id }

      expect(response).to have_http_status(:forbidden)
    end

    it 'creates a challenge and redirects to the show page' do
      contester1
      contester2
      login_as(team1_leader)

      expect do
        post '/challenges', params: {
          challenge: {
            contester1_id: contester1.id,
            contester2_id: contester2.id,
            match_time: 2.days.from_now,
            mandatory: false,
            details: 'Request spec challenge'
          }
        }
      end.to change(Challenge, :count).by(1)

      expect(response).to redirect_to(challenge_path(Challenge.last))
    end

    it 'accepts a pending challenge and creates a match' do
      challenge = Challenge.create!(
        contester1: contester1,
        contester2: contester2,
        user: team1_leader,
        match_time: 2.days.from_now,
        mandatory: false,
        details: 'Pending challenge'
      )
      login_as(team2_leader)

      expect do
        patch "/challenges/#{challenge.id}", params: {
          commit: 'Accept',
          challenge: { response: 'Accepted' }
        }
      end.to change(Match, :count).by(1)

      expect(response).to have_http_status(:ok)
      expect(challenge.reload.status).to eq(Challenge::STATUS_ACCEPTED)
    end

    it 'declines a pending challenge without creating a match' do
      challenge = Challenge.create!(
        contester1: contester1,
        contester2: contester2,
        user: team1_leader,
        match_time: 2.days.from_now,
        mandatory: false,
        details: 'Pending challenge'
      )
      login_as(team2_leader)

      expect do
        patch "/challenges/#{challenge.id}", params: {
          commit: 'Decline',
          challenge: { response: 'No thanks', map2_id: map.id }
        }
      end.not_to change(Match, :count)

      expect(response).to have_http_status(:ok)
      expect(challenge.reload.status).to eq(Challenge::STATUS_DECLINED)
    end

    it 'destroys a pending challenge for the challenging leader' do
      challenge = Challenge.create!(
        contester1: contester1,
        contester2: contester2,
        user: team1_leader,
        match_time: 2.days.from_now,
        mandatory: false,
        details: 'Pending challenge'
      )
      login_as(team1_leader)

      delete "/challenges/#{challenge.id}"

      expect(response).to have_http_status(:ok)
      expect(response.body).to include(I18n.t(:challenges_cleared))
      expect(Challenge.exists?(challenge.id)).to be(false)
    end
  end
end
