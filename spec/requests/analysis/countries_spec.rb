# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Analysis::CountriesController', type: :request do
  describe 'GET /analysis/countries' do
    it 'renders account and round participant charts' do
      user = create(:user, steamid: '0:1:201', country: 'US')
      round = Round.create!(server_name: 'Country request test', start_time: Time.zone.parse('2026-01-03 12:00:00'))
      Rounder.create!(round: round, steamid: "STEAM_#{user.steamid}", team: 1, share: 1.0)
      4.times do |number|
        player = create(:user, steamid: "0:1:20#{number + 2}", country: 'US')
        Rounder.create!(round: round, steamid: "STEAM_#{player.steamid}", team: 1, share: 1.0)
      end
      create_analysis_skill_for_user(batch_id: 1, user: user, model: 'dl', skill: 25.0)

      get '/analysis/countries'

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('Country analysis')
      expect(response.body).to include('ENSL players by country')
      expect(response.body).to include('DL skill by country')
      expect(response.body).to include('data-controller="country-statistics-chart"')
    end

    it 'renders a clear empty state without player accounts' do
      get '/analysis/countries'

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('No player accounts are available yet.')
    end
  end
end
