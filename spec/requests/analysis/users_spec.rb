# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Analysis::UsersController', type: :request do
  describe 'GET /analysis/users' do
    it 'renders the ranking table for known players' do
      user = create(:user, username: 'RankedPlayer', country: 'FI')
      create_analysis_skill_for_user(batch_id: 1, user: user, model: 'os', skill: 25.5)

      get '/analysis/users'

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('RankedPlayer')
      expect(response.body).to include('flag-fi')
    end

    it 'renders without error when there is no analysis data yet' do
      get '/analysis/users'

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('No analysis results are available yet.')
    end

    it 'selects the default minimum-games threshold' do
      get '/analysis/users'

      document = Nokogiri::HTML(response.body)
      expect(document.at_css('#min_games option[selected]')['value']).to eq('70')
    end

    it 'uses the requested sort in the table defaults' do
      user = create(:user, username: 'RankedPlayer')
      create_analysis_skill_for_user(batch_id: 1, user: user, model: 'os', skill: 25.5)

      get '/analysis/users', params: { min_games: 25, sort: 'wins', direction: 'descending' }

      document = Nokogiri::HTML(response.body)
      table = document.at_css('#player-rankings')
      expect(table['data-sortable-table-default-key-value']).to eq('wins')
      expect(table['data-sortable-table-default-direction-value']).to eq('descending')
    end
  end
end
