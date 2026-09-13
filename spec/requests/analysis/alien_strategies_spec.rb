# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Analysis::AlienStrategiesController', type: :request do
  def create_strategy_result(strategy:, metric:, value:, milestone:)
    create(:analysis_result, batch_id: 1, model: 'alien_strategy', steamid: strategy,
                             metric: metric, value: value, milestone: milestone)
  end

  it 'defaults to the top twenty-five qualifying six-player strategies with ten rounds' do
    10.times do |index|
      create_strategy_result(strategy: 'gorge,skulk,skulk,skulk,skulk,skulk',
                             metric: 'alien_win', value: 900, milestone: index)
    end

    get '/analysis/alien_strategies'

    expect(response).to have_http_status(:ok)
    expect(response.body).to include('six-player strategies', 'top 25', 'Minimum rounds per group:')
    expect(response.body).to include('Gorge', 'Alien win rate')
    expect(Nokogiri::HTML(response.body).css('.alien-strategy-role').size).to eq(6)
  end

  it 'accepts the median win-time minimum filter' do
    10.times do |index|
      create_strategy_result(strategy: 'fade,skulk,skulk,skulk,skulk,skulk',
                             metric: 'alien_win', value: 1800, milestone: index)
    end

    get '/analysis/alien_strategies', params: { min_median_win_time: 1200 }

    expect(response).to have_http_status(:ok)
    expect(response.body).to include('Median win at least:', '30:00', 'Fade')
  end

  it 'offers a best-across-limits action filter' do
    get '/analysis/alien_strategies', params: { action_limit: 'best' }

    expect(response).to have_http_status(:ok)
    expect(response.body).to include('best across limits')
  end
end
