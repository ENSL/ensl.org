# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Analysis::PickOrdersController', type: :request do
  describe 'GET /analysis/pick_orders' do
    it 'renders the pick order ranking table for known players' do
      ns1 = create(:category, :game, name: 'NS1')
      captain_user = create(:user)
      fast_pick_user = create(:user, username: 'FastPick')

      5.times do
        gather = create(:gather, category: ns1)
        captain = create(:gatherer, gather: gather, user: captain_user, team: 1, pick_order: 1)
        gather.update!(captain1_id: captain.id)
        create(:gatherer, gather: gather, user: fast_pick_user, team: 2, pick_order: 3)
      end

      get '/analysis/pick_orders', params: { min_games: 5 }

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('NS1 Gather Rankings')
      expect(response.body).to include('FastPick')
      expect(response.body).not_to include(captain_user.username)
    end

    it 'renders without error when there is no gather data yet' do
      get '/analysis/pick_orders'

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('No NS1 gather draft data is available yet.')
    end
  end
end
