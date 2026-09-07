# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Analysis::ActivityController', type: :request do
  def activity(day:, hour:, rounds:)
    create(:analysis_result, batch_id: AnalysisResult::CURRENT_SNAPSHOT_BATCH_ID,
                             steamid: day.to_s, model: 'time_of_week', metric: 'round_count',
                             milestone: hour, value: rounds)
  end

  describe 'GET /analysis/activity' do
    it 'explains that there is nothing to show yet when no rounds are imported' do
      get '/analysis/activity'

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('No round activity data is available yet')
    end

    it 'renders the weekday heatmap and the busiest slot' do
      activity(day: 6, hour: 20, rounds: 2)

      get '/analysis/activity'

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('Play times')
      expect(response.body).to include('Saturday')
      expect(response.body).to include('busiest slot is Saturday')
      expect(response.body).to include('data-controller="activity-chart"')
    end
  end
end
