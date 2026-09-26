# frozen_string_literal: true

require 'rails_helper'

RSpec.feature 'Analysis map balance page', :js, type: :feature do
  def seed_map(map, values)
    create_analysis_row(batch_id: AnalysisResult::CURRENT_SNAPSHOT_BATCH_ID, model: 'map_balance',
                        values: { 'map_name' => map }.merge(values))
  end

  before do
    seed_map('ns_altair', 'total_games' => 20, 'marine_wins' => 8, 'alien_wins' => 12,
                          'marine_win_percentage' => 40.0, 'alien_win_percentage' => 60.0)
    seed_map('ns_tanith', 'total_games' => 12, 'marine_wins' => 9, 'alien_wins' => 3,
                          'marine_win_percentage' => 75.0, 'alien_win_percentage' => 25.0)
    seed_map('ns_hera', 'total_games' => 5, 'marine_wins' => 2, 'alien_wins' => 3)
  end

  def map_names
    page.all('#map-balance tbody tr td:first-child').map(&:text)
  end

  scenario 'renders the balance chart from the current snapshot' do
    visit '/analysis/maps'

    expect(page).to have_css('canvas')

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

    # Default order: best marine win percentage first, with missing values last.
    expect(map_names).to eq(%w[ns_tanith ns_altair ns_hera])

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
