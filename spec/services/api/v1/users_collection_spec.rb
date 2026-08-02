# frozen_string_literal: true

require 'rails_helper'

describe Api::V1::UsersCollection do
  describe '#execute_query' do
    let!(:unrelated_user) { create(:user_with_team) }

    describe 'when there are users with no teams' do
      let!(:users) { create_list(:user, 3) }
      let(:collection) { Api::V1::UsersCollection.new(User.where(id: users.map(&:id))) }

      it 'returns only the requested users in ID order' do
        expect(collection.execute_query.map { |row| row[5] }).to eq(users.sort_by(&:id).map(&:id))
      end

      it 'returns nil team columns' do
        expect(collection.execute_query.map { |row| row[2..4] }).to all(eq([nil, nil, nil]))
      end
    end

    describe 'when there are some users with teams' do
      let!(:users_with_team) { create_list(:user_with_team, 3) }
      let(:collection) { Api::V1::UsersCollection.new(User.where(id: users_with_team.map(&:id))) }

      it 'returns one complete row per requested user' do
        expected_rows = users_with_team.sort_by(&:id).map do |user|
          [user.username, user.steamid, user.team.name, user.team.tag, user.team[:logo], user.id]
        end

        expect(collection.execute_query).to eq(expected_rows)
      end
    end
  end

  describe '#data' do
    let!(:user_without_team) { create(:user) }
    let!(:user_with_team) { create(:user_with_team) }
    let(:users) { [user_without_team, user_with_team].sort_by(&:id) }
    let(:collection) { Api::V1::UsersCollection.new(User.where(id: users.map(&:id))) }

    it 'maps users with and without teams to the API payload' do
      expect(collection.data).to eq(
        users: [
          {
            id: user_without_team.id,
            username: user_without_team.username,
            steamid: user_without_team.steamid,
            team: { name: nil, tag: nil, logo: nil }
          },
          {
            id: user_with_team.id,
            username: user_with_team.username,
            steamid: user_with_team.steamid,
            team: {
              name: user_with_team.team.name,
              tag: user_with_team.team.tag,
              logo: user_with_team.team[:logo]
            }
          }
        ]
      )
    end
  end
end
