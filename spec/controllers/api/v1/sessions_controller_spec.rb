# frozen_string_literal: true

require 'rails_helper'

# rubocop:disable Metrics/BlockLength
describe Api::V1::SessionsController do
  before do
    request.accept = 'application/json'
  end

  describe '#me' do
    context 'when user is signed in' do
      let(:user) { create(:user) }

      before do
        session[:user] = user.id
      end

      it 'returns success status' do
        get :me
        expect(response).to have_http_status(:success)
      end

      it 'returns signed_in as true' do
        get :me
        expect(json['signed_in']).to eq(true)
      end

      it 'returns user id and email' do
        get :me
        expect(json['user']).to be_present
        expect(json['user']['id']).to eq(user.id)
        expect(json['user']['email']).to eq(user.email)
      end

      it 'returns complete JSON structure' do
        get :me
        expect(json).to have_key('signed_in')
        expect(json).to have_key('user')
        expect(json['user']).to have_key('id')
        expect(json['user']).to have_key('email')
      end
    end

    context 'when user is not signed in' do
      it 'returns unauthorized status' do
        get :me
        expect(response).to have_http_status(:unauthorized)
      end

      it 'returns signed_in as false' do
        get :me
        expect(json['signed_in']).to eq(false)
      end

      it 'does not include user data' do
        get :me
        expect(json).not_to have_key('user')
      end
    end

    context 'when session has invalid user id' do
      before do
        session[:user] = 999_999 # Non-existent user ID
      end

      it 'returns unauthorized status' do
        get :me
        expect(response).to have_http_status(:unauthorized)
      end

      it 'returns signed_in as false' do
        get :me
        expect(json['signed_in']).to eq(false)
      end
    end

    context 'with different user properties' do
      let(:user_with_long_email) { create(:user, email: 'very.long.email.address@example.com') }

      before do
        session[:user] = user_with_long_email.id
      end

      it 'returns correct email regardless of length' do
        get :me
        expect(json['user']['email']).to eq('very.long.email.address@example.com')
      end
    end
  end
end
# rubocop:enable Metrics/BlockLength
