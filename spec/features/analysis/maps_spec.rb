# frozen_string_literal: true

require 'rails_helper'

RSpec.feature 'Analysis map balance page', type: :feature, js: true do
  def seed_map_metric(map, metric, value)
    create(:analysis_result, batch_id: AnalysisResult::CURRENT_SNAPSHOT_BATCH_ID,
                             steamid: map, model: 'map_balance', metric: metric, value: value)
  end

  before do
    seed_map_metric('ns_altair', 'total_games', 20)
    seed_map_metric('ns_altair', 'marine_wins', 8)
    seed_map_metric('ns_altair', 'alien_wins', 12)
    seed_map_metric('ns_altair', 'marine_win_percentage', 40.0)
    seed_map_metric('ns_altair', 'alien_win_percentage', 60.0)

    seed_map_metric('ns_tanith', 'total_games', 12)
    seed_map_metric('ns_tanith', 'marine_wins', 9)
    seed_map_metric('ns_tanith', 'alien_wins', 3)
    seed_map_metric('ns_tanith', 'marine_win_percentage', 75.0)
    seed_map_metric('ns_tanith', 'alien_win_percentage', 25.0)

    # No win-percentage rows recorded for this map -- exercises the "blanks sort last" rule.
    seed_map_metric('ns_hera', 'total_games', 5)
    seed_map_metric('ns_hera', 'marine_wins', 2)
    seed_map_metric('ns_hera', 'alien_wins', 3)
  end

  def map_names
    page.all('#map-balance tbody tr td:first-child').map(&:text)
  end

  scenario 'renders the balance chart from the current snapshot' do
    visit '/analysis/maps'

    expect(page).to have_selector('canvas')

    chart_labels = evaluate_script(<<~JS)
      (() => {
        const el = document.querySelector('[data-controller="map-balance-chart"]')
        const controller = window.Stimulus.getControllerForElementAndIdentifier(el, 'map-balance-chart')
        return controller.chart.data.labels
      })()
    JS

    expect(chart_labels).to contain_exactly('ns_altair', 'ns_tanith', 'ns_hera')
  end

  scenario 'sorts the table by column, blanks always last' do
    visit '/analysis/maps'

    # Default order from the server: most-played map first.
    expect(map_names).to eq(%w[ns_altair ns_tanith ns_hera])

    find('#map-balance thead th', text: 'Games').click
    expect(map_names).to eq(%w[ns_hera ns_tanith ns_altair])

    find('#map-balance thead th', text: 'Games').click
    expect(map_names).to eq(%w[ns_altair ns_tanith ns_hera])

    find('#map-balance thead th', text: 'Marine win %').click
    expect(map_names.last).to eq('ns_hera')

    find('#map-balance thead th', text: 'Map').click
    expect(map_names).to eq(%w[ns_altair ns_hera ns_tanith])
  end
end
