# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Analysis::TechPathsController', type: :request do
  def round_with_research(result:, researches:)
    @round_number = (@round_number || 0) + 1
    start_time = Time.zone.parse('2024-01-01 20:00:00') + (@round_number * 1.hour)
    round = Round.create!(server_name: 'Test', map_name: 'ns_eclipse', start_time: start_time,
                          end_time: start_time + 20.minutes, result: result)
    researches.each_with_index do |research, index|
      LogLine.create!(round: round, event_type: 'research_start', param1: research,
                      created_at: start_time + index.minutes)
    end
  end

  describe 'GET /analysis/tech_paths' do
    it 'renders the winning tech paths with readable research names' do
      5.times do
        round_with_research(result: Round::RESULT_MARINE_WIN,
                            researches: %w[research_armorl1 research_weaponsl1 research_phasetech])
      end

      get '/analysis/tech_paths', params: { min_rounds: 5 }

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('Marine tech paths')
      expect(response.body).to include('Armor Level 1')
      expect(response.body).to include('Phase Technology')
    end

    it 'truncates paths to the selected maximum length' do
      5.times do
        round_with_research(result: Round::RESULT_MARINE_WIN,
                            researches: %w[research_armorl1 research_weaponsl1 research_phasetech])
      end

      get '/analysis/tech_paths', params: { path_length: 2, min_rounds: 5 }

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('Armor Level 1')
      expect(response.body).not_to include('Phase Technology')
    end

    it 'keeps the full research order when uncapped' do
      5.times do
        round_with_research(result: Round::RESULT_MARINE_WIN,
                            researches: %w[research_armorl1 research_weaponsl1 research_phasetech])
      end

      get '/analysis/tech_paths', params: { path_length: 'all', min_rounds: 5 }

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('Phase Technology')
    end

    it 'accepts a selected row limit and the all-qualifying option' do
      get '/analysis/tech_paths', params: { result_limit: '50' }

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('top 50')

      get '/analysis/tech_paths', params: { result_limit: 'all' }

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('all qualifying')
    end

    it 'says all qualifying paths are shown when the selected limit is not reached' do
      5.times do
        round_with_research(result: Round::RESULT_MARINE_WIN, researches: %w[research_weaponsl1])
      end

      get '/analysis/tech_paths', params: { min_rounds: 5, result_limit: 20 }

      expect(response.body).to include('all 1 qualifying paths below')
      expect(response.body).not_to include('the best 1 by win rate')
    end

    it 'renders an empty-state message when nothing meets the minimum' do
      get '/analysis/tech_paths', params: { min_rounds: 50 }

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('was used in 50 or more rounds')
    end

    it 'ignores unsupported filter values instead of erroring' do
      get '/analysis/tech_paths', params: { path_length: '999', min_rounds: 'lots' }

      expect(response).to have_http_status(:ok)
    end
  end
end
