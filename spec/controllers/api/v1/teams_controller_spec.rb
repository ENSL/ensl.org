require "spec_helper"

describe Api::V1::TeamsController do
  before do
    request.accept = "application/json"
  end

  describe "#show" do
    before(:each) do
      @user = create :user
      @team = create(:team, founder: @user)
    end

    def team_expectation(json, team)
      expect(json["id"]).to eq(team.id)
      expect(json["name"]).to eq(team.name)
      expect(json["tag"]).to eq(team.tag)
      expect(json["logo"]).to eq(team.logo.url)
    end

    it "returns team data with empty roster" do
      teamers = @user.teamers.of_team(@team).active
      expect(teamers.length).to eq(1)
      teamers[0].destroy

      get :show, id: @team.id

      expect(response).to be_success
      team_expectation(json, @team)
      expect(json["roster"]).to be_empty
    end

    it "returns team data with a roster" do
      get :show, id: @team.id

      expect(response).to be_success
      team_expectation(json, @team)
      expect(json["roster"].count).to eq(1)

      roster_user = json["roster"][0]
      expect(roster_user["userid"]).to eq(@user.id)
      expect(roster_user["name"]).to eq(@user.username)
      expect(roster_user["steamid"]).to eq(@user.steamid)
      expect(roster_user["rank"]).to eq(Teamer::RANK_LEADER)
      expect(roster_user["primary"]).to eq(true)
    end

    it "returns 404 if team does not exist" do
      expect { get :show, id: -1 }
        .to raise_error(ActionController::RoutingError)
    end
  end

  describe "#index" do
    before do
      5.times { create(:user_with_team) }
    end

    it "returns all teams" do
      teams = Team.all

      get :index

      expect(response).to be_success
      expect(json["teams"].size).to eq(teams.size)
    end

    it "returns the excpected JSON keys" do
      get :index
      team_json = json["teams"].first

      expect(team_json).to have_key("id")
      expect(team_json).to have_key("name")
      expect(team_json).to have_key("tag")
      expect(team_json).to have_key("logo")
    end
  end
end
