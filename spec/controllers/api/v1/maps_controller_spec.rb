require 'rails_helper'

module Api
  module V1
  end
end

describe Api::V1::MapsController do
  before do
    request.accept = "application/json"
    create_list :map, 20
  end

  describe '#index' do
    it "return N maps" do
      get :index
      expect(response).to have_http_status(:success)
      expect(json["maps"].length).to eq(20)
    end

    # FIXME. Find the right map id
    it "return right map id" do
      skip
      map = create(:map)
      get :index
      expect(json["maps"].last["id"]).to eq(map.id)
    end
  end
end
