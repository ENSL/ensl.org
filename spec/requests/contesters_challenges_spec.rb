# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Contesters and Challenges controllers', type: :request do
  let(:admin) { create(:user, :admin) }

  def login_as(account)
    post '/sessions/login', params: { login: { username: account.username, password: account.raw_password } }
    follow_redirect! if response.redirect?
    expect(flash[:notice]).to be_present
  end

  describe 'ContestersController' do
    let(:contest) { create(:contest) }

    it 'shows active members for open contests' do
      contester = create(:contester, contest: contest)
      active_member = create(:user)
      removed_member = create(:user)
      Teamer.create!(user: active_member, team: contester.team, rank: Teamer::RANK_MEMBER)
      Teamer.create!(user: removed_member, team: contester.team, rank: Teamer::RANK_REMOVED)

      get "/contesters/#{contester.id}"

      expect(response).to have_http_status(:ok)
      expect(response.body).to include(active_member.username)
      expect(response.body).not_to include(removed_member.username)
    end

    it 'shows removed members for closed contests' do
      closed_contest = create(:contest)
      contester = create(:contester, contest: closed_contest)
      closed_contest.update!(status: Contest::STATUS_CLOSED)
      removed_member = create(:user)
      Teamer.create!(user: removed_member, team: contester.team, rank: Teamer::RANK_REMOVED)

      get "/contesters/#{contester.id}"

      expect(response).to have_http_status(:ok)
      expect(response.body).to include(removed_member.username)
    end

    it 'allows admins to load the edit form' do
      contester = create(:contester, contest: contest)
      login_as(admin)

      get "/contesters/#{contester.id}/edit"

      expect(response).to have_http_status(:ok)
    end

    it 'returns 403 when a non-admin tries to edit' do
      contester = create(:contester, contest: contest)
      login_as(create(:user))

      get "/contesters/#{contester.id}/edit"

      expect(response).to have_http_status(:forbidden)
    end

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

    it 'returns 403 when a non-admin tries to create a contester' do
      team = create(:team)
      login_as(create(:user))

      expect do
        post '/contesters', params: {
          contester: {
            contest_id: contest.id,
            team_id: team.id
          }
        }
      end.not_to change(Contester, :count)

      expect(response).to have_http_status(:forbidden)
    end

    it 'returns 422 for invalid create params' do
      login_as(admin)

      expect do
        post '/contesters', params: {
          contester: {
            contest_id: contest.id,
            team_id: nil
          }
        }
      end.to raise_error(ActionView::MissingTemplate)
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

    it 'updates a non-ladder contester' do
      non_ladder_contest = create(:contest, :bracket)
      contester = create(:contester, contest: non_ladder_contest)
      login_as(admin)

      patch "/contesters/#{contester.id}", params: {
        contester: {
          contest_id: non_ladder_contest.id,
          team_id: contester.team_id,
          extra: 5
        }
      }

      expect(response).to redirect_to(edit_contest_path(non_ladder_contest, anchor: 'teams'))
      expect(contester.reload.extra).to eq(5)
    end

    it 're-renders edit when a contester update is invalid' do
      non_ladder_contest = create(:contest, :bracket)
      contester = create(:contester, contest: non_ladder_contest)
      login_as(admin)

      patch "/contesters/#{contester.id}", params: {
        contester: {
          contest_id: non_ladder_contest.id,
          team_id: contester.team_id,
          extra: 10_000
        }
      }

      expect(response).to have_http_status(:unprocessable_content)
      expect(response).to render_template(:edit)
    end

    it 'soft deletes a contester and redirects to the teams tab' do
      contester = create(:contester, contest: contest)
      login_as(admin)

      delete "/contesters/#{contester.id}"

      expect(response).to redirect_to(edit_contest_path(contest, anchor: 'teams'))
      expect(contester.reload.active).to be(false)
    end

    it 'allows leaders to destroy their own contesters' do
      leader = create(:user_with_team)
      led_contester = create(:contester, contest: contest, team: leader.team)
      login_as(leader)

      delete "/contesters/#{led_contester.id}"

      expect(response).to redirect_to(edit_contest_path(contest, anchor: 'teams'))
      expect(led_contester.reload.active).to be(false)
    end

    it 'returns 403 when an unrelated user tries to destroy a contester' do
      contester = create(:contester, contest: contest)
      login_as(create(:user))

      delete "/contesters/#{contester.id}"

      expect(response).to have_http_status(:forbidden)
      expect(contester.reload.active).to be(true)
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

    it 're-renders new when a challenge is invalid after access is allowed' do
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
            details: 'x' * 256
          }
        }
      end.not_to change(Challenge, :count)

      expect(response).to have_http_status(:ok)
      expect(response).to render_template(:new)
    end

    it 'returns 403 when a non-participant tries to create a challenge' do
      contester1
      contester2
      login_as(outsider)

      expect do
        post '/challenges', params: {
          challenge: {
            contester1_id: contester1.id,
            contester2_id: contester2.id,
            match_time: 2.days.from_now,
            mandatory: false,
            details: 'Blocked challenge'
          }
        }
      end.not_to change(Challenge, :count)

      expect(response).to have_http_status(:forbidden)
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

    it 'marks a pending challenge as default time' do
      challenge = Challenge.create!(
        contester1: contester1,
        contester2: contester2,
        user: team1_leader,
        match_time: 2.days.from_now,
        mandatory: false,
        details: 'Pending challenge'
      )
      login_as(team2_leader)

      patch "/challenges/#{challenge.id}", params: {
        commit: 'Default time',
        challenge: { response: 'Default it' }
      }

      expect(response).to have_http_status(:ok)
      expect(challenge.reload.status).to eq(Challenge::STATUS_DEFAULT)
    end

    it 'marks a pending challenge as forfeit' do
      challenge = Challenge.create!(
        contester1: contester1,
        contester2: contester2,
        user: team1_leader,
        match_time: 2.days.from_now,
        mandatory: false,
        details: 'Pending challenge'
      )
      login_as(team2_leader)

      patch "/challenges/#{challenge.id}", params: {
        commit: 'Forfeit',
        challenge: { response: 'We forfeit' }
      }

      expect(response).to have_http_status(:ok)
      expect(challenge.reload.status).to eq(Challenge::STATUS_FORFEIT)
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

    it 'returns 403 when a non-recipient tries to update a challenge' do
      challenge = Challenge.create!(
        contester1: contester1,
        contester2: contester2,
        user: team1_leader,
        match_time: 2.days.from_now,
        mandatory: false,
        details: 'Pending challenge'
      )
      login_as(outsider)

      patch "/challenges/#{challenge.id}", params: {
        commit: 'Decline',
        challenge: { response: 'No access', map2_id: map.id }
      }

      expect(response).to have_http_status(:forbidden)
      expect(challenge.reload.status).to eq(Challenge::STATUS_PENDING)
    end

    it 'renders show without updating when a decline is invalid' do
      challenge = Challenge.create!(
        contester1: contester1,
        contester2: contester2,
        user: team1_leader,
        match_time: 2.days.from_now,
        mandatory: false,
        details: 'Pending challenge'
      )
      login_as(team2_leader)

      patch "/challenges/#{challenge.id}", params: {
        commit: 'Decline',
        challenge: { response: 'x' * 256, map2_id: map.id }
      }

      expect(response).to have_http_status(:ok)
      expect(response).to render_template(:show)
      expect(challenge.reload.status).to eq(Challenge::STATUS_PENDING)
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

      expect(response).to redirect_to(contest_path(contest))
      expect(flash[:notice]).to eq(I18n.t(:challenges_cleared))
      expect(Challenge.exists?(challenge.id)).to be(false)
    end

    it 'returns a plain-text success response for non-html requests' do
      challenge = Challenge.create!(
        contester1: contester1,
        contester2: contester2,
        user: team1_leader,
        match_time: 2.days.from_now,
        mandatory: false,
        details: 'Pending challenge'
      )
      login_as(team1_leader)

      delete "/challenges/#{challenge.id}", headers: { 'ACCEPT' => 'text/plain' }

      expect(response).to have_http_status(:ok)
      expect(response.body).to include(I18n.t(:challenges_cleared))
      expect(Challenge.exists?(challenge.id)).to be(false)
    end

    it 'returns 403 when a non-participant tries to destroy a pending challenge' do
      challenge = Challenge.create!(
        contester1: contester1,
        contester2: contester2,
        user: team1_leader,
        match_time: 2.days.from_now,
        mandatory: false,
        details: 'Pending challenge'
      )
      login_as(outsider)

      delete "/challenges/#{challenge.id}"

      expect(response).to have_http_status(:forbidden)
      expect(Challenge.exists?(challenge.id)).to be(true)
    end
  end
end
