require 'rails_helper'

RSpec.describe Vote, type: :model do
  let(:user) { create(:user) }
  let(:category) { create(:category, :game) }
  let(:gather) { create(:gather, category: category) }

  let!(:gatherer) { Gatherer.create!(gather: gather, user: user, confirm: true) }

  def create_gather_map(name: 'ns_test')
    map = create(:map, name: name, category_id: category.id)
    GatherMap.create!(gather: gather, map: map, votes: 0)
  end

  def create_gather_server(id: nil)
    server = create(:server, active: true)
    attrs = { gather: gather, server: server, votes: 0 }
    attrs[:id] = id if id
    GatherServer.create!(**attrs)
  end

  it 'allows map vote even if server vote exists' do
    gather_map = create_gather_map(name: 'ns_alpha')
    gather_server = create_gather_server(id: gather_map.id)

    expect(gather_server.id).to eq(gather_map.id)

    Vote.create!(user: user, votable: gather_server)

    map_vote = Vote.new(user: user, votable: gather_map)
    expect(map_vote.can_create?(user)).to be true
    expect { map_vote.save! }.to change(Vote, :count).by(1)
  end

  it 'prevents duplicate vote on the same map but allows another map' do
    gather_map_one = create_gather_map(name: 'ns_map_one')
    gather_map_two = create_gather_map(name: 'ns_map_two')

    Vote.create!(user: user, votable: gather_map_one)

    duplicate_vote = Vote.new(user: user, votable: gather_map_one)
    expect(duplicate_vote.can_create?(user)).to be false
    expect(duplicate_vote.valid?).to be false
    expect(duplicate_vote.errors[:user_id]).to be_present

    other_map_vote = Vote.new(user: user, votable: gather_map_two)
    expect(other_map_vote.can_create?(user)).to be true
    expect { other_map_vote.save! }.to change(Vote, :count).by(1)
  end
end
