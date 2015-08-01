require 'spec_helper'

describe Api::V1::ServersController do
  before do
    request.accept = 'application/json'
  end 

  describe '#index' do
    let!(:server) { create :server, :active }
    let!(:inactive_server) { create :server, :inactive }

    it 'returns a list of servers' do
      get :index
      expect(response).to be_success
      expect(json['servers'].length).to eq(1)
      json_server = json['servers'][0]
      expect(json_server['id']).to eq(server.id)
    end
  end
end