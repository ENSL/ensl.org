require 'spec_helper'

describe Api::V1::UsersController do
  before do
    request.accept = 'application/json'
  end

  describe '#index' do
    before do
      10.times { create(:user_with_team) }
    end

    it 'returns all users and associated teams' do
      users = User.all

      get :index

      expect(response).to be_success
      expect(json["users"].size).to eq(users.size)
    end

    it 'returns the excpected JSON keys' do
      get :index

      user_json = json["users"].first
      nested_team_json = user_json["team"]
      
      expect(user_json).to have_key("username")
      expect(user_json).to have_key("steamid")
      expect(user_json).to have_key("team")
      expect(nested_team_json).to have_key("name")
      expect(nested_team_json).to have_key("tag")
      expect(nested_team_json).to have_key("logo")
    end
  end
end
