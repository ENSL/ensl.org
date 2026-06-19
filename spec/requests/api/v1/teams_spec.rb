# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Api::V1::TeamsController', type: :request do
  let(:json_headers) { { 'ACCEPT' => 'application/json' } }

  describe 'GET /api/v1/teams/:id' do
    let!(:founder) { create :user }
    let!(:team_member) { create :user }
    let!(:ex_team_member) { create :user }
    let!(:team) { create :team, founder: founder }

    before do
      Teamer.create!(user: team_member, team: team, rank: Teamer::RANK_MEMBER)
      Teamer.create!(user: ex_team_member, team: team, rank: Teamer::RANK_REMOVED)
    end

    it 'returns team data with active members' do
      get "/api/v1/teams/#{team.id}", headers: json_headers

      expect(response).to have_http_status(:success)
      expect(json['id']).to eq(team.id)
      expect(json['name']).to eq(team.name)
      json['members'].each do |member|
        expect(team.teamers.active.map(&:user_id)).to include(member['id'])
      end
    end

    it 'returns 404 if the team is not found', :skip_log_error_check do
      get "/api/v1/teams/#{team.id + 1}", headers: json_headers

      expect(response).to have_http_status(:not_found)
    end
  end
end
