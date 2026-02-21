# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Custom URL show', type: :request do
  it 'returns 404 for text format when slug is missing' do
    get '/ads-txt.txt'

    expect(response).to have_http_status(:not_found)
    expect(response.body).to eq('')
  end

  it 'returns 404 when custom url points to a deleted article' do
    article = create(:article)
    custom_url = CustomUrl.create!(name: 'slug-test', article_id: article.id)
    article.destroy!

    get "/#{custom_url.name}"

    expect(response).to have_http_status(:not_found)
  end
end
