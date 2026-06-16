require 'rails_helper'

RSpec.describe 'Api::V1::MapsController', type: :request do
  let(:json_headers) { { 'ACCEPT' => 'application/json' } }

  before do
    create_list :map, 20
  end

  describe 'GET /api/v1/maps' do
    it 'returns maps as json' do
      get '/api/v1/maps', headers: json_headers

      expect(response).to have_http_status(:success)
      expect(json['maps'].length).to eq(20)
    end

    it 'includes the created map ids' do
      map = create(:map)

      get '/api/v1/maps', headers: json_headers

      ids = json['maps'].map { |m| m['id'] }
      expect(ids).to include(map.id)
    end
  end
end