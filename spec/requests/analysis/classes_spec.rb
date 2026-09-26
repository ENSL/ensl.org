# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Analysis::ClassesController', type: :request do
  describe 'GET /analysis/classes' do
    it 'renders the class-performance table from the latest historical batch' do
      user = create(:user, username: 'ClassExpert')
      create_analysis_user(batch_id: 2, user_id: user.id, steam_id: user.steamid)
      create_analysis_class_stat(batch_id: 2, user_id: user.id, class_name: 'fade', damage: 500,
                                 resources_spent: 25, sample_size: 25)

      get '/analysis/classes', params: { class_name: 'fade', min_games: 25 }

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('ClassExpert', 'Fade', 'K/D', 'Dmg', 'Dmg/min', 'Dmg/res', 'Minimum games:')
      expect(response.body).not_to include('>Class</th>', 'Resources</th>', 'Wins</th>', 'Losses</th>',
                                           '>Damage</span>', 'Damage/min', 'Damage/resource')

      document = Nokogiri::HTML(response.body)
      table = document.at_css('#class-performance')
      expect(table['data-sortable-table-default-key-value']).to eq('kill_death_ratio')
      expect(table['data-sortable-table-default-direction-value']).to eq('descending')
    end

    it 'uses the player rankings minimum-games options' do
      get '/analysis/classes'

      document = Nokogiri::HTML(response.body)
      expect(document.css('#min_games option').map { |option| option['value'] })
        .to eq(PlayerRankingQuery::MIN_GAMES_OPTIONS.map(&:to_s))
      expect(document.at_css('#min_games option[selected]')['value'])
        .to eq(PlayerRankingQuery::DEFAULT_MIN_GAMES.to_s)
    end
  end
end
