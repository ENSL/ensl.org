require 'rails_helper'

describe PluginController do
  render_views

  describe "#user" do
    before do
      create :group, :donors
      create :group, :champions
    end

    let!(:user) { create :user_with_team }

    it "returns user data" do
      get :user, id: user.steamid
      expect(response).to be_success
      expect(response.body).to include(user.username)
    end

    it "definitely does not return IP address" do
      last_ip = "127.0.0.1"
      user.lastip = last_ip
      user.save!
      get :user, id: user.steamid
      expect(response).to be_success
      expect(response).to_not include(last_ip)
    end
  end
end
