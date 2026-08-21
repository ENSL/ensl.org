# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Analysis::TeamsController', type: :request do
  def ns2_contest
    create(:contest, id: [Contest.maximum(:id).to_i, Contest::NS2_FIRST_CONTEST_ID].max + 1)
  end

  describe 'GET /analysis/teams' do
    it 'renders the ranking table for teams that have played' do
      contest = ns2_contest
      contester1 = create(:contester, contest: contest, team: create(:team, name: 'Rated Squad'))
      contester2 = create(:contester, contest: contest)
      create(:match, contest: contest, contester1: contester1, contester2: contester2, match_time: 1.day.ago)
        .update!(score1: 3, score2: 1)

      get '/analysis/teams', params: { game: 'NS2', min_matches: 1 }

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('Rated Squad')
      expect(response.body).to include('data-tooltip')
    end

    it 'renders without error when the game has no results yet' do
      get '/analysis/teams', params: { game: 'NS1' }

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('No team results are available for NS1 yet.')
    end

    it 'falls back to the default game for an unknown one' do
      get '/analysis/teams', params: { game: 'NS3' }

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("No team results are available for #{TeamRankingQuery::DEFAULT_GAME} yet.")
    end
  end
end
