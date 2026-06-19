# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Votes CSRF protection', type: :request do
  around do |example|
    original = ActionController::Base.allow_forgery_protection
    ActionController::Base.allow_forgery_protection = true
    example.run
  ensure
    ActionController::Base.allow_forgery_protection = original
  end

  let(:invalid_vote_params) do
    {
      authenticity_token: 'invalid-token',
      vote: {
        votable_id: 1,
        votable_type: 'GatherMap'
      }
    }
  end

  it 'rejects invalid CSRF token for HTML with graceful redirect and flash', :expect_log_error do
    post votes_path, params: invalid_vote_params

    expect(response).to have_http_status(:found)
    expect(response).to redirect_to(root_path)
    expect(flash[:error]).to match(/page expired|try again/i)
  end

  it 'rejects invalid CSRF token for Turbo Stream with graceful 422 response', :expect_log_error do
    post votes_path,
         params: invalid_vote_params,
         headers: { 'ACCEPT' => Mime[:turbo_stream].to_s }

    expect(response).to have_http_status(:unprocessable_entity)
    expect(response.media_type).to eq(Mime[:turbo_stream].to_s)
    expect(response.body).to include('turbo-stream')
    expect(response.body).to include('target="notification"')
    expect(response.body).to match(/page expired|try again/i)
  end
end
