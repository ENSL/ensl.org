require "spec_helper"

describe Api::V1::UsersController do
  before do
    request.accept = "application/json"
  end

  describe "#show" do
    before(:each) do
      @user = create :user, :chris
    end

    def user_expectation(json, user)
      expect(json["id"]).to eq(user.id)
      expect(json["username"]).to eq(user.username)
      expect(json["country"]).to eq(user.country)
      expect(json["time_zone"]).to eq(user.time_zone)
      expect(json["admin"]).to eq(user.admin?)
      expect(json["referee"]).to eq(user.ref?)
      expect(json["caster"]).to eq(user.caster?)
      expect(json["moderator"]).to eq(user.gather_moderator?)
      expect(json).to have_key("steam")
      expect(json["steam"]).to have_key("id")
      expect(json["steam"]).to have_key("url")
      expect(json["steam"]).to have_key("nickname")
      expect(json["bans"]["mute"]).to eq(false)
      expect(json["bans"]["gather"]).to eq(false)
      expect(json["bans"]["site"]).to eq(false)
      expect(json["team"]).to be_nil
    end

    it "returns user data" do
      get :show, id: @user.id

      expect(response).to be_success
      user_expectation(json, @user)
    end

    it "returns user data for query with id specified as format" do
      get :show, id: @user.id, format: "id"

      expect(response).to be_success
      user_expectation(json, @user)
    end

    it "returns user data for a numeric steamid query" do
      m = @user.steamid.match(/\A0:([01]):(\d{1,10})\Z/)
      steamid = (m[2].to_i << 1) + m[1].to_i

      get :show, id: steamid, format: "steamid"

      expect(response).to be_success
      user_expectation(json, @user)
    end

    it "returns user data for a string steamid query" do
      get :show, id: @user.steamid, format: "steamidstr"

      expect(response).to be_success
      user_expectation(json, @user)
    end

    it "returns nulled steam data for users who had invalid steam ids" do
      @user.steamid = nil
      @user.save!

      get :show, id: @user.id

      expect(response).to be_success
      expect(json["steam"]).to be_nil
    end

    it "returns gather moderator status" do
      group = create :group, :gather_moderator
      create :grouper, user: @user, group: group
      get :show, id: @user.id
      expect(json["moderator"]).to eq(true)
    end

    it "returns 404 if user does not exist" do
      expect { get :show, id: -1 }.to raise_error(ActionController::RoutingError)
    end

    it "returns 404 if user does not exist by steamid" do
      expect { get :show, id: -1, format: "steamid" }.to raise_error(ActionController::RoutingError)
    end

    it "queries the steam condenser for an invalid steamid" do
      @user.update_attribute(:steamid, "0:0:0")

      get :show, id: @user.id

      expect(response).to be_success
      expect(json["steam"]).to_not be_nil
      expect(json["steam"]["id"]).to eq(@user.steamid)
      expect(json["steam"]["url"]).to be_nil
      expect(json["steam"]["nickname"]).to be_nil
    end

    it "returns correct ban if user muted" do
      create :ban, :mute, user: @user
      get :show, id: @user.id
      expect(response).to be_success
      expect(json["bans"]["mute"]).to eq(true)
    end

    it "returns correct ban if user gather banned" do
      create :ban, :gather, user: @user
      get :show, id: @user.id
      expect(response).to be_success
      expect(json["bans"]["gather"]).to eq(true)
    end

    it "returns correct ban if user site banned" do
      create :ban, :site, user: @user
      get :show, id: @user.id
      expect(response).to be_success
      expect(json["bans"]["site"]).to eq(true)
    end

    it "returns team information" do
      @user.destroy
      @user_with_team = create :user_with_team, :chris
      get :show, id: @user_with_team.id
      expect(response).to be_success
      expect(json["team"]["id"]).to eq(@user_with_team.team.id)
      expect(json["team"]["name"]).to eq(@user_with_team.team.name)
    end
  end

  describe "#index" do
    before do
      5.times { create(:user_with_team) }
    end

    it "returns all users and associated teams" do
      users = User.all

      get :index

      expect(response).to be_success
      expect(json["users"].size).to eq(users.size)
    end

    it "returns the excpected JSON keys" do
      get :index
      user_json = json["users"].first
      nested_team_json = user_json["team"]

      expect(user_json).to have_key("username")
      expect(user_json).to have_key("id")
      expect(user_json).to have_key("steamid")
      expect(user_json).to have_key("team")
      expect(nested_team_json).to have_key("name")
      expect(nested_team_json).to have_key("tag")
      expect(nested_team_json).to have_key("logo")
    end
  end
end
