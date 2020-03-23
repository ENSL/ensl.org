require "rails_helper"

describe Api::V1::TeamsController do
  before do
    request.accept = "application/json"
  end

  describe "#show" do
    before(:each) do
      @founder = create :user
      @team_member = create :user
      @ex_team_member = create :user
      @team = create :team, founder: @founder
      Teamer.create user: @team_member, team: @team, rank: Teamer::RANK_MEMBER
      Teamer.create user: @ex_team_member, team: @team, rank: Teamer::RANK_REMOVED
    end

    it "returns team data" do
      get :show, id: @team.id
      expect(response).to be_success
      expect(json["id"]).to eq(@team.id)
      expect(json["name"]).to eq(@team.name)

      json["members"].each do |member|
        expect(@team.teamers.active.map(&:user_id)).to include(member["id"])
      end
    end

    it "returns 404 if team not found" do
      expect {
        get :show, id: Team.last.id + 1
      }.to raise_error(ActionController::RoutingError)
    end
  end
end
