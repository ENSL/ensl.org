# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Analysis::HomeController', type: :request do
  describe 'GET /analysis' do
    it 'renders the stats hub with links to each listing page' do
      get '/analysis'

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('Stats')
      expect(response.body).to include(analysis_users_path)
      expect(response.body).to include(analysis_maps_path)
      expect(response.body).to include(analysis_pick_orders_path)
      expect(response.body).to include(analysis_tech_paths_path)
      expect(response.body).to include(statistics_rounds_path)
      expect(response.body).to include('NS1 Rankings')
      expect(response.body).to include('NS1 Map balance')
      expect(response.body).to include('NS1 Gather Rankings')
      expect(response.body).to include('NS1 Marine tech paths')
      expect(response.body).to include('Team rankings')
      expect(response.body).to include('Round Data Over Time')
    end
  end
end
