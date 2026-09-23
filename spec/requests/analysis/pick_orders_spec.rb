# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Analysis::PickOrdersController', type: :request do
  describe 'GET /analysis/pick_orders' do
    it 'renders the pick order ranking table for known players' do
      ns1 = create(:category, :game, name: 'NS1')
      captain_user = create(:user)
      fast_pick_user = create(:user, username: 'FastPick')
      minimum_games = PlayerRankingQuery::MIN_GAMES_OPTIONS.first

      minimum_games.times do
        gather = create(:gather, category: ns1)
        captain = create(:gatherer, gather: gather, user: captain_user, team: 1, pick_order: 1)
        gather.update!(captain1_id: captain.id)
        create(:gatherer, gather: gather, user: fast_pick_user, team: 2, pick_order: 3)
      end

      get '/analysis/pick_orders', params: { min_games: minimum_games }

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('NS1 Gather Rankings')
      expect(response.body).to include('FastPick')
      expect(response.body).not_to include(captain_user.username)
    end

    it 'renders without error when there is no gather data yet' do
      get '/analysis/pick_orders'

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('No NS1 gather pick data is available yet.')
    end

    it 'keeps supporting the legacy min_picks parameter' do
      minimum_games = PlayerRankingQuery::MIN_GAMES_OPTIONS.first
      get '/analysis/pick_orders', params: { min_picks: minimum_games }

      document = Nokogiri::HTML(response.body)
      expect(response).to have_http_status(:ok)
      expect(document.at_css('#min_games option[selected]')['value']).to eq(minimum_games.to_s)
      expect(document.css('#min_games option').map { |option| option['value'] })
        .to eq(PlayerRankingQuery::MIN_GAMES_OPTIONS.map(&:to_s))
    end
  end
end
