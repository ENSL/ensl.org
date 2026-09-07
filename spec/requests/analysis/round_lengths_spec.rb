# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Analysis::RoundLengthsController', type: :request do
  def round(minutes:, result:, map_name: 'ns_eclipse')
    @round_number = (@round_number || 0) + 1
    start_time = Time.zone.parse('2024-01-01 20:00:00') + (@round_number * 1.hour)
    Round.create!(server_name: "Test #{@round_number}", map_name: map_name, start_time: start_time,
                  end_time: start_time + (minutes * 60), result: result)
  end

  describe 'GET /analysis/round_lengths' do
    it 'explains that there is nothing to show yet when no rounds are imported' do
      get '/analysis/round_lengths'

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('No finished rounds are available')
    end

    it 'renders the length buckets and the per-map breakdown' do
      round(minutes: 10, result: Round::RESULT_MARINE_WIN, map_name: 'ns_veil')
      round(minutes: 30, result: Round::RESULT_ALIEN_WIN, map_name: 'ns_veil')

      get '/analysis/round_lengths'

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('Round length')
      expect(response.body).to include('data-controller="round-length-chart"')
      expect(response.body).to include('id="round-lengths"')
      expect(response.body).to include('id="round-lengths-by-map"')
      expect(response.body).to include('ns_veil')
    end

    it 'narrows the buckets to the selected map' do
      round(minutes: 10, result: Round::RESULT_MARINE_WIN, map_name: 'ns_veil')
      round(minutes: 10, result: Round::RESULT_ALIEN_WIN, map_name: 'ns_eclipse')

      get '/analysis/round_lengths', params: { map: 'ns_veil' }

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('1 finished round on ns_veil')
    end

    it 'falls back to every map when the map param is not one we have rounds for' do
      round(minutes: 10, result: Round::RESULT_MARINE_WIN, map_name: 'ns_veil')

      get '/analysis/round_lengths', params: { map: 'ns_nowhere' }

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('across every map')
    end
  end
end
