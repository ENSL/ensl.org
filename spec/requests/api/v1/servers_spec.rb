require 'rails_helper'

RSpec.describe 'Api::V1::ServersController', type: :request do
  let(:json_headers) { { 'ACCEPT' => 'application/json' } }

  describe 'GET /api/v1/servers' do
    let!(:server) { create :server, :active }
    let!(:inactive_server) { create :server, :inactive }

    it 'returns only active servers' do
      get '/api/v1/servers', headers: json_headers

      expect(response).to have_http_status(:success)
      expect(json['servers'].length).to eq(1)
      expect(json['servers'][0]['id']).to eq(server.id)
      expect(json['servers'][0]['id']).not_to eq(inactive_server.id)
    end
  end
end