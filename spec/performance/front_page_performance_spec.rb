# frozen_string_literal: true

require 'rails_helper'
require 'rspec-benchmark'

RSpec.describe 'Front page performance', type: :request, performance: true do
  include RSpec::Benchmark::Matchers

  let!(:seed_stats) { seed_front_page_performance_data! }

  it 'stays under a query-count budget for root rendering' do
    query_count = count_sql_queries { get '/' }

    expect(response).to have_http_status(:ok)
    expect(query_count).to be <= 35
    expect(seed_stats[:articles_seeded]).to be_positive
    expect(seed_stats[:comments_seeded]).to be_positive
  end

  it 'renders the root page within a baseline budget' do
    get '/'
    expect(response).to have_http_status(:ok)

    expect { get '/' }.to perform_under(1_500).ms.sample(3).times
  end
end
