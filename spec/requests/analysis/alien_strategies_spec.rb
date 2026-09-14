# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Analysis::AlienStrategiesController', type: :request do
  def create_strategy_result(strategy:, metric:, value:, milestone:)
    create(:analysis_result, batch_id: 8, model: 'alien_strategy', steamid: strategy,
                             metric: metric, value: value, milestone: milestone)
  end

  it 'defaults to the top twenty-five qualifying six-player strategies with ten rounds' do
    10.times do |index|
      create_strategy_result(strategy: 'gorge,skulk,skulk,skulk,skulk,skulk',
                             metric: 'alien_win', value: 900, milestone: index)
    end

    get '/analysis/alien_strategies', params: { min_rounds: 10 }

    expect(response).to have_http_status(:ok)
    expect(response.body).to include('six-player strategies', 'top 25', 'Minimum rounds:')
    expect(response.body).to include('Gorge', 'Alien win rate')
    expect(Nokogiri::HTML(response.body).css('.alien-strategy-role').size).to eq(6)
  end

  it 'accepts the median win-time minimum filter' do
    10.times do |index|
      create_strategy_result(strategy: 'fade,skulk,skulk,skulk,skulk,skulk',
                             metric: 'alien_win', value: 1800, milestone: index)
    end

    get '/analysis/alien_strategies', params: { min_rounds: 10, min_median_win_time: 1200 }

    expect(response).to have_http_status(:ok)
    expect(response.body).to include('Median win at least:', '30:00', 'Fade')
  end

  it 'offers a best-across-limits action filter' do
    get '/analysis/alien_strategies', params: { action_limit: 'best' }

    expect(response).to have_http_status(:ok)
    expect(response.body).to include('best across limits')
  end

  it 'keeps selected filters in the form and renders matching role actions' do
    10.times do |index|
      create_strategy_result(strategy: 'gorge+hive,skulk,skulk,skulk,skulk,skulk', metric: 'alien_win', value: 1800,
                             milestone: index + 20)
    end

    get '/analysis/alien_strategies', params: { action_limit: 2, min_rounds: 10, result_limit: 'all',
                                                result_view: 'role_actions', coalesce_chambers: '1',
                                                min_median_win_time: 1200, strategy_filter: 'Gorge, Hive' }

    document = Nokogiri::HTML(response.body)
    expect(response).to have_http_status(:ok)
    expect(document.at_css('#action_limit option[selected]')['value']).to eq('2')
    expect(document.at_css('#result_view option[selected]')['value']).to eq('role_actions')
    expect(document.at_css('#coalesce_chambers option[selected]')['value']).to eq('1')
    expect(document.at_css('#min_median_win_time option[selected]')['value']).to eq('1200')
    expect(document.at_css('#strategy_filter')['value']).to eq('gorge+hive')
    expect(response.body).to include('Gorge', 'Hive', 'Alien win rate')
  end

  it 'renders the no-results state for a valid but unmatched filter' do
    10.times do |index|
      create_strategy_result(strategy: 'gorge,skulk,skulk,skulk,skulk,skulk', metric: 'alien_win', value: 900,
                             milestone: index + 30)
    end

    get '/analysis/alien_strategies', params: { min_rounds: 10, strategy_filter: 'onos' }

    expect(response).to have_http_status(:ok)
    expect(response.body).to include('No strategy met the', '10 or more rounds')
  end
end
