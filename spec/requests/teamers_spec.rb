# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'TeamersController', type: :request do
  let(:user) { create(:user) }

  def login_as(account)
    post '/users/login', params: { login: { username: account.username, password: account.raw_password } }
    follow_redirect! if response.redirect?
    expect(flash[:notice]).to be_present
  end

  describe 'GET /teamers' do
    it 'returns 406 because no html index is implemented' do
      get teamers_path

      expect(response).to have_http_status(:not_acceptable)
    end
  end

  describe 'POST /teamers' do
    it 'creates a join request and replaces an existing application' do
      old_team = create(:team)
      new_team = create(:team)
      old_application = create(:teamer, user: user, team: old_team, rank: Teamer::RANK_JOINER)
      login_as(user)

      expect do
        post teamers_path,
             params: { teamer: { team_id: new_team.id, user_id: user.id } },
             headers: { 'HTTP_REFERER' => team_path(new_team) }
      end.not_to change(Teamer, :count)

      expect(response).to redirect_to(team_path(new_team))
      expect(Teamer.where(team: new_team, user: user).joining.exists?).to be true
      expect(Teamer.exists?(old_application.id)).to be false
      expect(flash[:notice]).to include(new_team.to_s)
    end

    it 'returns 403 for guests' do
      team = create(:team)

      expect do
        post teamers_path, params: { teamer: { team_id: team.id, user_id: user.id } }
      end.not_to change(Teamer, :count)

      expect(response).to have_http_status(:forbidden)
    end

    it 'redirects back with an error when the request is invalid' do
      team = create(:team)
      create(:teamer, user: user, team: team, rank: Teamer::RANK_JOINER)
      login_as(user)

      expect do
        post teamers_path,
             params: { teamer: { team_id: team.id, user_id: user.id } },
             headers: { 'HTTP_REFERER' => team_path(team) }
      end.not_to change(Teamer, :count)

      expect(response).to redirect_to(team_path(team))
      expect(flash[:error]).to be_present
    end

    it 'redirects turbo-stream requests to the team page after success' do
      team = create(:team)
      login_as(user)

      post teamers_path,
           params: { teamer: { team_id: team.id, user_id: user.id } },
           headers: { 'ACCEPT' => Mime[:turbo_stream].to_s }

      expect(response).to redirect_to(team_path(team))
      expect(Teamer.where(team: team, user: user).joining.exists?).to be true
    end
  end

  describe 'DELETE /teamers/:id' do
    it 'removes a join request for the requesting user via html' do
      teamer = create(:teamer, user: user, rank: Teamer::RANK_JOINER)
      login_as(user)

      expect do
        delete teamer_path(teamer), headers: { 'HTTP_REFERER' => team_path(teamer.team) }
      end.to change(Teamer, :count).by(-1)

      expect(response).to redirect_to(team_path(teamer.team))
    end

    it 'soft-removes an active member when a leader deletes them' do
      leader = create(:user)
      team = create(:team, founder: leader)
      member_user = create(:user)
      member_user.update_column(:team_id, team.id)
      teamer = create(:teamer, user: member_user, team: team, rank: Teamer::RANK_MEMBER)
      login_as(leader)

      expect do
        delete teamer_path(teamer), headers: { 'HTTP_REFERER' => team_path(team) }
      end.not_to change(Teamer, :count)

      expect(response).to redirect_to(team_path(team))
      expect(teamer.reload.rank).to eq(Teamer::RANK_REMOVED)
      expect(member_user.reload.team).to be_nil
    end

    it 'returns no content for turbo-stream deletions' do
      teamer = create(:teamer, user: user, rank: Teamer::RANK_JOINER)
      login_as(user)

      expect do
        delete teamer_path(teamer), headers: { 'ACCEPT' => Mime[:turbo_stream].to_s }
      end.to change(Teamer, :count).by(-1)

      expect(response).to have_http_status(:no_content)
    end

    it 'returns 403 for unauthorized users' do
      outsider = create(:user)
      teamer = create(:teamer)
      login_as(outsider)

      expect do
        delete teamer_path(teamer)
      end.not_to change(Teamer, :count)

      expect(response).to have_http_status(:forbidden)
    end
  end
end
