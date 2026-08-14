# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Analysis::PickOrdersController', type: :request do
  describe 'GET /analysis/pick_orders' do
    it 'renders the pick order ranking table for known players' do
      ns1 = create(:category, :game, name: 'NS1')
      gather = create(:gather, category: ns1)
      captain = create(:gatherer, gather: gather, team: 1, pick_order: 1)
      gather.update!(captain1_id: captain.id)
      create(:gatherer, gather: gather, user: create(:user, username: 'FastPick'), team: 2, pick_order: 2)

      get '/analysis/pick_orders'

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('FastPick')
      expect(response.body).not_to include(captain.user.username)
    end

    it 'renders without error when there is no gather data yet' do
      get '/analysis/pick_orders'

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('No NS1 pick data is available yet.')
    end
  end
end
