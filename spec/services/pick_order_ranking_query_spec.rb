# frozen_string_literal: true

require 'rails_helper'

RSpec.describe PickOrderRankingQuery do
  let(:ns1) { create(:category, :game, name: 'NS1') }
  let(:minimum_games) { PlayerRankingQuery::MIN_GAMES_OPTIONS.first }

  def make_gather(category: ns1)
    create(:gather, category: category)
  end

  it 'ranks players by average pick order, excluding captain appearances' do
    captain1_user = create(:user)
    captain2_user = create(:user)
    fast_pick_user = create(:user)
    slow_pick_user = create(:user)

    minimum_games.times do
      gather = make_gather
      captain1 = create(:gatherer, gather: gather, user: captain1_user, team: 1, pick_order: 1)
      captain2 = create(:gatherer, gather: gather, user: captain2_user, team: 2, pick_order: 2)
      gather.update!(captain1_id: captain1.id, captain2_id: captain2.id)

      create(:gatherer, gather: gather, user: fast_pick_user, team: 1, pick_order: 3)
      create(:gatherer, gather: gather, user: slow_pick_user, team: 2, pick_order: 4)
    end

    rankings = described_class.call(game: 'NS1', min_games: minimum_games)

    users = rankings.map { |row| row[:user] }
    expect(users).to include(fast_pick_user, slow_pick_user)
    expect(users).not_to include(captain1_user, captain2_user)

    fast_row = rankings.find { |row| row[:user] == fast_pick_user }
    slow_row = rankings.find { |row| row[:user] == slow_pick_user }
    expect(fast_row[:average_pick_order]).to be < slow_row[:average_pick_order]
  end

  it 'does not affect a captain own ranking from other gathers where they were picked normally' do
    gather1 = make_gather
    captain = create(:gatherer, gather: gather1, team: 1, pick_order: 1)
    gather1.update!(captain1_id: captain.id)
    create(:gatherer, gather: gather1, team: 2, pick_order: 3)

    (minimum_games - 1).times do
      gather = make_gather
      create(:gatherer, gather: gather, user: captain.user, team: 1, pick_order: 3)
      create(:gatherer, gather: gather, team: 2, pick_order: 4)
    end

    rankings = described_class.call(game: 'NS1', min_games: minimum_games)
    captain_row = rankings.find { |row| row[:user] == captain.user }

    expect(captain_row[:average_pick_order]).to eq(3.0)
    expect(captain_row[:games_count]).to eq(minimum_games)
    expect(captain_row[:captain_percentage]).to eq(100.0 / minimum_games)
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

  it 'filters out players below the minimum games threshold' do
    gather = make_gather
    picked = create(:gatherer, gather: gather, team: 1, pick_order: 1)
    create(:gatherer, gather: gather, team: 2, pick_order: 2)

    rankings = described_class.call(game: 'NS1', min_games: minimum_games)

    expect(rankings.map { |row| row[:user] }).not_to include(picked.user)
  end

  it 'orders by the pick-order OpenSkill score by default' do
    strong_user = create(:user)
    weak_user = create(:user)

    minimum_games.times do
      gather = make_gather
      create(:gatherer, gather: gather, user: strong_user, team: 1, pick_order: 3)
      create(:gatherer, gather: gather, user: weak_user, team: 2, pick_order: 4)
    end

    rankings = described_class.call(game: 'NS1', min_games: minimum_games)
    strong_row = rankings.find { |row| row[:user] == strong_user }
    weak_row = rankings.find { |row| row[:user] == weak_user }

    expect(rankings.first[:user]).to eq(strong_user)
    expect(strong_row[:pick_openskill]).to be > weak_row[:pick_openskill]
  end

  it 'uses the player rankings default minimum games when no threshold is provided' do
    gather = make_gather
    picked = create(:gatherer, gather: gather, team: 1, pick_order: 3)
    create(:gatherer, gather: gather, team: 2, pick_order: 4)

    rankings = described_class.call(game: 'NS1')

    expect(rankings.map { |row| row[:user] }).not_to include(picked.user)
  end

  it 'reports captain percentage over all games' do
    4.times do
      gather = make_gather
      create(:gatherer, gather: gather, user: create(:user), team: 1, pick_order: 3)
      create(:gatherer, gather: gather, user: create(:user), team: 2, pick_order: 4)
    end

    target_user = create(:user)

    2.times do
      gather = make_gather
      captain = create(:gatherer, gather: gather, user: target_user, team: 1, pick_order: 1)
      gather.update!(captain1_id: captain.id)
      create(:gatherer, gather: gather, user: create(:user), team: 2, pick_order: 3)
    end

    (minimum_games - 2).times do
      gather = make_gather
      create(:gatherer, gather: gather, user: target_user, team: 1, pick_order: 3)
      create(:gatherer, gather: gather, user: create(:user), team: 2, pick_order: 4)
    end

    rankings = described_class.call(game: 'NS1', min_games: minimum_games)
    row = rankings.find { |entry| entry[:user] == target_user }

    expect(row[:games_count]).to eq(minimum_games)
    expect(row[:captain_percentage]).to eq((2.0 / minimum_games) * 100)
  end

  it 'uses the same minimum-games settings as player rankings' do
    expect(described_class::MIN_GAMES_OPTIONS).to equal(PlayerRankingQuery::MIN_GAMES_OPTIONS)
    expect(described_class::DEFAULT_MIN_GAMES).to eq(PlayerRankingQuery::DEFAULT_MIN_GAMES)
  end
end
