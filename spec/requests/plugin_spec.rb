require 'rails_helper'

RSpec.describe 'PluginController', type: :request do
  before do
    create :group, :donors
    create :group, :champions
  end

  let!(:user) { create :user_with_team }

  describe 'GET /plugin/user' do
    it 'returns user data' do
      get '/plugin/user', params: { id: user.steamid }

      expect(response).to have_http_status(:success)
      expect(response.body).to include(user.username)
    end

    it 'definitely does not return the ip address' do
      user.update!(lastip: '127.2.4.2')

      get '/plugin/user', params: { id: user.steamid }

      expect(response).to have_http_status(:success)
      expect(response.body).not_to include('127.2.4.2')
    end

    it 'returns fail when the user cannot be found' do
      get '/plugin/user', params: { id: '0:1:99999999' }

      expect(response).to have_http_status(:success)
      expect(response.body).to include('#FAIL#')
    end

    it 'includes role, team and channel data for privileged users' do
      donor_group = Group.find(Group::DONORS)
      champion_group = Group.find(Group::CHAMPIONS)
      privileged_user = create :user_with_team, :admin, :referee
      create :grouper, user: privileged_user, group: donor_group
      create :grouper, user: privileged_user, group: champion_group
      allow(Verification).to receive(:verify) { |value| value }

      get '/plugin/user', params: { id: privileged_user.steamid, ch: 'captains' }

      expect(response).to have_http_status(:success)
      expect(response.body).to include('Admin')
      expect(response.body).to include(Verification.uncrap(privileged_user.team.to_s))
      expect(response.body).to include('captains')
    end

    it 'falls back to no team when the user has none' do
      lone_user = create :user_with_team
      allow(lone_user).to receive(:team).and_return(nil)
      allow(lone_user).to receive(:current_teamer).and_return(double(rank_s: ''))
      allow(User).to receive(:where).with(steamid: lone_user.steamid).and_return(double(first: lone_user))
      allow(Verification).to receive(:verify) { |value| value }

      get '/plugin/user', params: { id: lone_user.steamid }

      expect(response).to have_http_status(:success)
      expect(response.body).to include('No Team')
    end
  end
end
