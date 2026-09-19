# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Analysis::UsersController', type: :request do
  describe 'GET /analysis/users' do
    it 'renders the ranking table for known players' do
      user = create(:user, username: 'RankedPlayer')
      create(:analysis_result, batch_id: 1, steamid: user.steamid, model: 'os', metric: 'skill', value: 25.5)

      get '/analysis/users'

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('RankedPlayer')
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
  end
end
