# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ClassPerformanceQuery do
  def create_result(batch_id:, steamid:, class_name:, metric:, value:)
    create(:analysis_result, batch_id: batch_id, steamid: steamid, model: "class_stats:#{class_name}",
                             metric: metric, value: value)
  end

  it 'pivots only the latest batch into map-independent player and class rows' do
    user = create(:user, steamid: '0:1:12345')
    create_result(batch_id: 1, steamid: user.steamid, class_name: 'skulk', metric: 'damage', value: 10)
    metrics = %w[kills deaths damage resources_spent minutes_played wins sample_size]
    metrics.zip([8, 4, 500, 25, 10, 3, 4]).each do |metric, value|
      create_result(batch_id: 2, steamid: 'STEAM_0:1:12345', class_name: 'skulk', metric: metric, value: value)
    end

    performance = described_class.call.first

    expect(performance).to include(user: user, class_name: 'skulk', damage: 500, damage_per_resource: 20,
                                   damage_per_minute: 50, kill_death_ratio: 2, win_rate: 0.75)
  end

  it 'does not calculate a damage-per-resource rate when no resources were spent' do
    user = create(:user)
    create_result(batch_id: 3, steamid: user.steamid, class_name: 'marine', metric: 'damage', value: 100)
    create_result(batch_id: 3, steamid: user.steamid, class_name: 'marine', metric: 'resources_spent', value: 0)

    expect(described_class.call.first[:damage_per_resource]).to be_nil
  end

  it 'does not calculate K/D when a player has no deaths' do
    user = create(:user)
    create_result(batch_id: 3, steamid: user.steamid, class_name: 'marine', metric: 'kills', value: 10)
    create_result(batch_id: 3, steamid: user.steamid, class_name: 'marine', metric: 'deaths', value: 0)

    expect(described_class.call.first[:kill_death_ratio]).to be_nil
  end

  it 'filters by class and minimum number of games from the latest batch' do
    user = create(:user)
    create_result(batch_id: 4, steamid: user.steamid, class_name: 'skulk', metric: 'sample_size', value: 25)
    create_result(batch_id: 4, steamid: user.steamid, class_name: 'fade', metric: 'sample_size', value: 50)

    performances = described_class.call(class_name: 'fade', min_games: 50)

    expect(performances).to have_attributes(size: 1)
    expect(performances.first[:class_name]).to eq('fade')
  end

  it 'returns available classes only from the latest batch' do
    user = create(:user)
    create_result(batch_id: 5, steamid: user.steamid, class_name: 'skulk', metric: 'sample_size', value: 30)
    create_result(batch_id: 6, steamid: user.steamid, class_name: 'fade', metric: 'sample_size', value: 30)

    expect(described_class.class_names).to eq(['fade'])
  end
end
