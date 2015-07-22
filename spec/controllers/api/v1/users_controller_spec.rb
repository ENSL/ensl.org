require 'spec_helper'

describe Api::V1::UsersController do
  before do
    request.accept = 'application/json'
  end

  describe '#show' do
    before do
      @user = create :user_with_team, :chris
    end

    it 'returns user data' do
      get :show, id: @user.id

      expect(response).to be_success
      expect(json['id']).to eq(@user.id)
      expect(json['username']).to eq(@user.username)
      expect(json['country']).to eq(@user.country)
      expect(json['time_zone']).to eq(@user.time_zone)
      expect(json['admin']).to eq(@user.admin?)
      expect(json).to have_key("steam")
      expect(json['steam']).to have_key("url")
      expect(json['steam']).to have_key("nickname")
    end

    it 'returns 404 if user does not exist' do
      expect {
        get :show, id: -1
      }.to raise_error(ActionController::RoutingError)
    end
  end

  describe '#index' do
    before do
      5.times { create(:user_with_team) }
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
