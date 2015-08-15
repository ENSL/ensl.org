require 'spec_helper'

describe Api::V1::MapsController do
  before do
    request.accept = 'application/json'
  end

  describe '#index' do
    let!(:map) { create :map }

    it 'returns a list of maps' do
      get :index
      expect(response).to be_success
      expect(json['maps'].length).to eq(1)
      json_map = json['maps'][0]
      expect(json_map['id']).to eq(map.id)
    end
  end
end

