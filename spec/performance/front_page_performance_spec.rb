# frozen_string_literal: true

require 'rails_helper'
require 'rspec-benchmark'

RSpec.describe 'Front page performance', type: :request do
  include RSpec::Benchmark::Matchers

  before do
    news_category = create(:category, :news)
    author = create(:user)

    articles = create_list(:article, 30, category: news_category, user: author)

    # Add comments on a subset of articles to exercise with_comments query paths.
    articles.first(10).each do |article|
      create_list(:comment, 3, commentable: article, user: author)
    end

    poll = Poll.new(question: 'Front page perf poll?')
    poll.options.build(option: 'Yes')
    poll.options.build(option: 'No')
    poll.save!
  end

  it 'renders the root page within a baseline budget' do
    get '/'
    expect(response).to have_http_status(:ok)

    expect { get '/' }.to perform_under(1_500).ms.sample(3).times
  end
end
