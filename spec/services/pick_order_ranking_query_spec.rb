# frozen_string_literal: true

require 'rails_helper'

RSpec.describe PickOrderRankingQuery do
  let(:ns1) { create(:category, :game, name: 'NS1') }

  def make_gather(category: ns1)
    create(:gather, category: category)
  end

  it 'ranks players by average pick order, excluding captain appearances' do
    gather = make_gather
    captain1 = create(:gatherer, gather: gather, team: 1, pick_order: 1)
    captain2 = create(:gatherer, gather: gather, team: 2, pick_order: 2)
    gather.update!(captain1_id: captain1.id, captain2_id: captain2.id)

    fast_pick = create(:gatherer, gather: gather, team: 1, pick_order: 3)
    slow_pick = create(:gatherer, gather: gather, team: 2, pick_order: 4)

    rankings = described_class.call(game: 'NS1')

    users = rankings.map { |row| row[:user] }
    expect(users).to include(fast_pick.user, slow_pick.user)
    expect(users).not_to include(captain1.user, captain2.user)

    fast_row = rankings.find { |row| row[:user] == fast_pick.user }
    slow_row = rankings.find { |row| row[:user] == slow_pick.user }
    expect(fast_row[:average_pick_order]).to be < slow_row[:average_pick_order]
  end

  it 'does not affect a captain own ranking from other gathers where they were picked normally' do
    gather1 = make_gather
    captain = create(:gatherer, gather: gather1, team: 1, pick_order: 1)
    gather1.update!(captain1_id: captain.id)
    create(:gatherer, gather: gather1, team: 2, pick_order: 2)

    gather2 = make_gather
    create(:gatherer, gather: gather2, user: captain.user, team: 1, pick_order: 5)
    other_captain = create(:gatherer, gather: gather2, team: 2, pick_order: 1)
    gather2.update!(captain2_id: other_captain.id)

    rankings = described_class.call(game: 'NS1')
    captain_row = rankings.find { |row| row[:user] == captain.user }

    expect(captain_row[:average_pick_order]).to eq(5.0)
    expect(captain_row[:picks_count]).to eq(1)
  end

  it 'excludes gathers for other games' do
    ns2 = create(:category, :game, name: 'NS2')
    gather = make_gather(category: ns2)
    create(:gatherer, gather: gather, team: 1, pick_order: 1)

    expect(described_class.call(game: 'NS1')).to be_empty
  end

  it 'excludes unpicked gatherers still in the lobby' do
    gather = make_gather
    create(:gatherer, gather: gather, team: nil, pick_order: nil)

    expect(described_class.call(game: 'NS1')).to be_empty
  end

  it 'filters out players below the minimum picks threshold' do
    gather = make_gather
    picked = create(:gatherer, gather: gather, team: 1, pick_order: 1)
    create(:gatherer, gather: gather, team: 2, pick_order: 2)

    rankings = described_class.call(game: 'NS1', min_picks: 5)

    expect(rankings.map { |row| row[:user] }).not_to include(picked.user)
  end
end
