require 'rails_helper'

RSpec.describe 'MatchProposalsController', type: :request do
  let(:team1_leader) { create(:user_with_team, username: 'team1_leader_req') }
  let(:team2_leader) { create(:user_with_team, username: 'team2_leader_req') }
  let(:admin) { create(:user, :admin) }
  let(:outsider) { create(:user) }
  let(:contest) { create(:contest) }
  let(:contester1) { create(:contester, contest: contest, team: team1_leader.team) }
  let(:contester2) { create(:contester, contest: contest, team: team2_leader.team) }
  let(:match) { create(:match, contest: contest, contester1: contester1, contester2: contester2) }

  def login_as(user)
    post '/users/login', params: { login: { username: user.username, password: user.raw_password } }
    follow_redirect! if response.redirect?
    expect(flash[:notice]).to be_present
  end

  describe 'GET /matches/:match_id/proposals' do
    it 'returns 403 for a non-participating user' do
      login_as(outsider)

      get "/matches/#{match.id}/proposals"

      expect(response).to have_http_status(:forbidden)
    end

    it 'returns 200 for an admin' do
      login_as(admin)

      get "/matches/#{match.id}/proposals"

      expect(response).to have_http_status(:ok)
    end
  end

  describe 'GET /matches/:match_id/proposals/new' do
    it 'redirects back to the proposals list when a confirmed proposal already exists' do
      create(:match_proposal, :confirmed, match: match, team: team1_leader.team)
      login_as(team2_leader)

      get "/matches/#{match.id}/proposals/new"

      expect(response).to redirect_to(match_proposals_path(match))
      expect(flash[:error]).to include('Cannot create a new proposal')
    end
  end

  describe 'POST /matches/:match_id/proposals' do
    it 'creates a pending proposal and sends a team message' do
      login_as(team1_leader)

      expect do
        post "/matches/#{match.id}/proposals", params: {
          match_proposal: {
            proposed_time: 2.days.from_now
          }
        }
      end.to change(MatchProposal, :count).by(1)
                                          .and change(Message, :count).by(1)

      expect(response).to redirect_to(match_proposals_path(match))
      expect(MatchProposal.last.status).to eq(MatchProposal::STATUS_PENDING)
      expect(MatchProposal.last.team).to eq(team1_leader.team)
    end
  end

  describe 'PATCH /matches/:match_id/proposals/:id' do
    let(:xhr_headers) { { 'X-Requested-With' => 'XMLHttpRequest' } }

    it 'returns 403 for non-XHR requests' do
      proposal = create(:match_proposal, match: match, team: team1_leader.team)
      login_as(team2_leader)

      patch "/matches/#{match.id}/proposals/#{proposal.id}", params: {
        match_proposal: { status: MatchProposal::STATUS_CONFIRMED }
      }

      expect(response).to have_http_status(:forbidden)
    end

    it 'returns 404 when the proposal does not belong to the nested match' do
      other_match = create(:match, contest: contest)
      proposal = create(:match_proposal, match: other_match, team: other_match.contester1.team)
      login_as(admin)

      patch "/matches/#{match.id}/proposals/#{proposal.id}",
            params: { match_proposal: { status: MatchProposal::STATUS_DELAYED } },
            headers: xhr_headers

      expect(response).to have_http_status(:not_found)
      expect(response.parsed_body.dig('error', 'code')).to eq(404)
    end

    it 'returns 403 when the proposing team tries to confirm its own proposal' do
      proposal = create(:match_proposal, :pending, :in_far_future, match: match, team: team1_leader.team)
      login_as(team1_leader)

      patch "/matches/#{match.id}/proposals/#{proposal.id}",
            params: { match_proposal: { status: MatchProposal::STATUS_CONFIRMED } },
            headers: xhr_headers

      expect(response).to have_http_status(:forbidden)
      expect(response.parsed_body.dig('error', 'code')).to eq(403)
      expect(proposal.reload.status).to eq(MatchProposal::STATUS_PENDING)
    end

    it 'updates the status and returns accepted json for a valid transition' do
      proposal = create(:match_proposal, :pending, :in_far_future, match: match, team: team1_leader.team)
      login_as(team2_leader)

      expect do
        patch "/matches/#{match.id}/proposals/#{proposal.id}",
              params: { match_proposal: { status: MatchProposal::STATUS_CONFIRMED } },
              headers: xhr_headers
      end.to change(Message, :count).by(1)

      expect(response).to have_http_status(:accepted)
      expect(response.parsed_body['status']).to eq('Confirmed')
      expect(proposal.reload.status).to eq(MatchProposal::STATUS_CONFIRMED)
    end

    it 'does not send a message when the status does not change' do
      proposal = create(:match_proposal, :pending, :in_far_future, match: match, team: team1_leader.team)
      login_as(team1_leader)

      expect do
        patch "/matches/#{match.id}/proposals/#{proposal.id}",
              params: { match_proposal: { status: MatchProposal::STATUS_PENDING } },
              headers: xhr_headers
      end.not_to change(Message, :count)

      expect(response).to have_http_status(:accepted)
      expect(response.parsed_body['status']).to eq('Pending')
    end
  end
end
