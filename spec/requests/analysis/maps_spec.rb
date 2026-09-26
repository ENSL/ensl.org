# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Analysis::MapsController', type: :request do
  describe 'GET /analysis/maps' do
    it 'renders map balance rows from current snapshot data' do
      create_analysis_row(batch_id: AnalysisResult::CURRENT_SNAPSHOT_BATCH_ID, model: 'map_balance',
                          values: { 'map_name' => 'ns_tram', 'total_games' => 12, 'marine_wins' => 7,
                                    'alien_wins' => 5 })

      get '/analysis/maps'

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('Map balance')
      expect(response.body).to include('ns_tram')
      expect(response.body).to include('12')
    end

    it 'renders empty-state message when no map balance data exists' do
      get '/analysis/maps'

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('No map balance data is available yet.')
    end
  end
end
