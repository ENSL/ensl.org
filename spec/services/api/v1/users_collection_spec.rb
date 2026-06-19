# frozen_string_literal: true

require 'rails_helper'

describe Api::V1::UsersCollection do
  describe '#execute_query' do
    describe 'when there are users with no teams' do
      let!(:users) { create_list(:user, 3) }
      let(:collection) { Api::V1::UsersCollection.new(User.where(id: users.map(&:id))) }

      it 'returns 3 results' do
        expect(collection.execute_query.size).to eq(3)
      end
    end

    # FIXME: weird user count issue, expected 3 but got 300+
    describe 'when there are some users with teams' do
      let!(:users_with_team) { create_list(:user_with_team, 3) }
      let(:collection) { Api::V1::UsersCollection.new(User.where(id: users_with_team.map(&:id))) }

      it 'returns 3 results' do
        expect(collection.execute_query.size).to eq(3)
      end

      it 'returns 6 columns' do
        expect(collection.execute_query.first.size).to eq(6)
      end
    end
  end
end
