# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Analysis::ClassesController', type: :request do
  describe 'GET /analysis/classes' do
    it 'renders the class-performance table from the latest historical batch' do
      user = create(:user, username: 'ClassExpert')
      create(:analysis_result, batch_id: 2, steamid: user.steamid, model: 'class_stats:fade', metric: 'damage',
                               value: 500)
      create(:analysis_result, batch_id: 2, steamid: user.steamid, model: 'class_stats:fade',
                               metric: 'resources_spent', value: 25)
      create(:analysis_result, batch_id: 2, steamid: user.steamid, model: 'class_stats:fade',
                               metric: 'sample_size', value: 25)

      get '/analysis/classes', params: { class_name: 'fade', min_games: 25 }

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('ClassExpert', 'Fade', 'K/D', 'Damage/resource', 'Minimum games:')
      expect(response.body).not_to include('>Class</th>', 'Resources</th>', 'Wins</th>', 'Losses</th>')
    end
  end
end
