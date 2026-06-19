# frozen_string_literal: true

require 'rails_helper'
require 'ostruct'

RSpec.describe 'Api::V1::UsersController', type: :request do
  let(:json_headers) { { 'ACCEPT' => 'application/json' } }

  def user_expectation(user_json, user)
    expect(user_json['id']).to eq(user.id)
    expect(user_json['username']).to eq(user.username)
    expect(user_json['country']).to eq(user.country)
    expect(user_json['time_zone']).to eq(user.time_zone)
    expect(user_json['admin']).to eq(user.admin?)
    expect(user_json['referee']).to eq(user.ref?)
    expect(user_json['caster']).to eq(user.caster?)
    expect(user_json['moderator']).to eq(user.gather_moderator?)
    expect(user_json['contributor']).to eq(user.contributor?)
    expect(user_json).to have_key('steam')
    expect(user_json['steam']).to have_key('id')
    expect(user_json['steam']).to have_key('url')
    expect(user_json['steam']).to have_key('nickname')
    expect(user_json['bans']['mute']).to eq(false)
    expect(user_json['bans']['gather']).to eq(false)
    expect(user_json['bans']['site']).to eq(false)
    expect(user_json['team']).to be_nil
  end

  describe 'GET /api/v1/users/:id' do
    let!(:user) { create :user, :chris }

    before do
      allow(SteamCondenser::Community::SteamId).to receive(:from_steam_id)
        .and_return(OpenStruct.new(base_url: nil, nickname: nil, id: user.steamid))
    end

    it 'returns user data' do
      get "/api/v1/users/#{user.id}", headers: json_headers

      expect(response).to have_http_status(:success)
      user_expectation(json, user)
    end

    it 'returns user data for query with id specified as format' do
      get "/api/v1/users/show/#{user.id}", params: { format: 'id' }, headers: json_headers

      expect(response).to have_http_status(:success)
      user_expectation(json, user)
    end

    it 'returns user data for a numeric steamid query' do
      match = user.steamid.match(/\A0:([01]):(\d{1,10})\Z/)
      steamid = (match[2].to_i << 1) + match[1].to_i

      get "/api/v1/users/show/#{steamid}", params: { format: 'steamid' }, headers: json_headers

      expect(response).to have_http_status(:success)
      user_expectation(json, user)
    end

    it 'returns user data for a string steamid query' do
      get "/api/v1/users/show/#{user.steamid}", params: { format: 'steamidstr' }, headers: json_headers

      expect(response).to have_http_status(:success)
      user_expectation(json, user)
    end

    it 'returns nulled steam data for users without steam ids' do
      user.update!(steamid: nil)

      get "/api/v1/users/#{user.id}", headers: json_headers

      expect(response).to have_http_status(:success)
      expect(json['steam']).to be_nil
    end

    it 'returns gather moderator status' do
      group = create :group, :gather_moderator
      create :grouper, user: user, group: group

      get "/api/v1/users/#{user.id}", headers: json_headers

      expect(json['moderator']).to eq(true)
    end

    it 'returns 404 if the user does not exist' do
      get '/api/v1/users/-1', headers: json_headers

      expect(response).to have_http_status(:not_found)
      expect(json['error']).to eq('User not found')
    end

    it 'returns 404 if the user does not exist by steamid' do
      get '/api/v1/users/show/-1', params: { format: 'steamid' }, headers: json_headers

      expect(response).to have_http_status(:not_found)
      expect(json['error']).to eq('User not found')
    end

    it 'returns nil steam metadata for invalid steam community lookups' do
      user.update_attribute(:steamid, '0:0:0')

      get "/api/v1/users/#{user.id}", headers: json_headers

      expect(response).to have_http_status(:success)
      expect(json['steam']).not_to be_nil
      expect(json['steam']['id']).to eq(user.steamid)
      expect(json['steam']['url']).to be_nil
      expect(json['steam']['nickname']).to be_nil
    end

    it 'returns correct ban if the user is muted' do
      create :ban, :mute, user: user

      get "/api/v1/users/#{user.id}", headers: json_headers

      expect(response).to have_http_status(:success)
      expect(json['bans']['mute']).to eq(true)
    end

    it 'returns correct ban if the user is site banned' do
      create :ban, :site, user: user

      get "/api/v1/users/#{user.id}", headers: json_headers

      expect(response).to have_http_status(:success)
      expect(json['bans']['site']).to eq(true)
    end

    it 'returns team information' do
      user.destroy
      user_with_team = create :user_with_team, :chris

      get "/api/v1/users/#{user_with_team.id}", headers: json_headers

      expect(response).to have_http_status(:success)
      expect(json['team']['id']).to eq(user_with_team.team.id)
      expect(json['team']['name']).to eq(user_with_team.team.name)
    end
  end

  describe 'GET /api/v1/users' do
    before do
      5.times { create(:user_with_team) }
    end

    it 'returns all users and associated teams' do
      users = User.all

      get '/api/v1/users', headers: json_headers

      expect(response).to have_http_status(:success)
      expect(json['users'].size).to eq(users.size)
    end

    it 'returns the expected json keys' do
      get '/api/v1/users', headers: json_headers
      user_json = json['users'].first
      nested_team_json = user_json['team']

      expect(user_json).to have_key('username')
      expect(user_json).to have_key('id')
      expect(user_json).to have_key('steamid')
      expect(user_json).to have_key('team')
      expect(nested_team_json).to have_key('name')
      expect(nested_team_json).to have_key('tag')
      expect(nested_team_json).to have_key('logo')
    end
  end
end
