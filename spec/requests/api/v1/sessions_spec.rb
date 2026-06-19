# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Api::V1::SessionsController', type: :request do
  let(:json_headers) { { 'ACCEPT' => 'application/json' } }

  describe 'GET /api/v1/sessions/me' do
    context 'when user is signed in' do
      let(:user) { create(:user) }

      before do
        login_as(user)
      end

      it 'returns success status and user payload' do
        get '/api/v1/sessions/me', headers: json_headers

        expect(response).to have_http_status(:success)
        expect(json['signed_in']).to eq(true)
        expect(json['user']['id']).to eq(user.id)
        expect(json['user']['email']).to eq(user.email)
      end
    end

    context 'when user is not signed in' do
      it 'returns unauthorized without user data' do
        get '/api/v1/sessions/me', headers: json_headers

        expect(response).to have_http_status(:unauthorized)
        expect(json['signed_in']).to eq(false)
        expect(json).not_to have_key('user')
      end
    end

    context 'when session has invalid user id' do
      it 'returns unauthorized' do
        user = create(:user)
        login_as(user)
        user.destroy!

        get '/api/v1/sessions/me', headers: json_headers

        expect(response).to have_http_status(:unauthorized)
        expect(json['signed_in']).to eq(false)
      end
    end

    context 'with different user properties' do
      it 'returns the current email value' do
        user = create(:user, email: 'very.long.email.address@example.com')
        login_as(user)

        get '/api/v1/sessions/me', headers: json_headers

        expect(json['user']['email']).to eq('very.long.email.address@example.com')
      end
    end
  end
end
