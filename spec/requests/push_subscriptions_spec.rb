# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'PushSubscriptionsController', type: :request do
  let(:user) { create(:user) }
  let(:endpoint) { 'https://push.example.com/subscription/abc123' }
  let(:subscription_payload) do
    { subscription: { endpoint: endpoint, keys: { p256dh: 'public-key', auth: 'auth-secret' } } }
  end

  def login_as(account)
    post '/sessions/login', params: { login: { username: account.username, password: account.raw_password } }
  end

  describe 'POST /push_subscription' do
    it 'stores the subscription and enables the profile preference' do
      user.profile.update!(notify_push_gather: false)
      login_as(user)

      post '/push_subscription', params: subscription_payload, as: :json

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body['enabled']).to be true
      expect(user.push_subscriptions.pluck(:endpoint)).to eq([endpoint])
      expect(user.profile.reload.notify_push_gather).to be true
    end

    it 'reuses the record when the same endpoint is registered twice' do
      login_as(user)

      2.times { post '/push_subscription', params: subscription_payload, as: :json }

      expect(PushSubscription.where(endpoint: endpoint).count).to eq(1)
    end

    it 'rejects anonymous visitors' do
      post '/push_subscription', params: subscription_payload, as: :json

      expect(response).to have_http_status(:forbidden)
      expect(PushSubscription.count).to be_zero
    end
  end

  describe 'DELETE /push_subscription' do
    it 'removes the subscription and disables the profile preference' do
      user.profile.update!(notify_push_gather: true)
      user.push_subscriptions.create!(endpoint: endpoint, p256dh_key: 'public-key', auth_key: 'auth-secret')
      login_as(user)

      delete '/push_subscription', params: { endpoint: endpoint }, as: :json

      expect(response).to have_http_status(:ok)
      expect(user.push_subscriptions.count).to be_zero
      expect(user.profile.reload.notify_push_gather).to be false
    end
  end

  describe 'the gather page toggle' do
    let(:gather) { create(:gather, :running) }

    it 'is rendered when VAPID keys are configured' do
      allow(WebPushCredentials).to receive_messages(configured?: true, public_key: 'public')
      login_as(user)

      get "/gathers/#{gather.id}"

      expect(response.body).to include('gather-push-toggle')
    end

    it 'is hidden when VAPID keys are missing' do
      allow(WebPushCredentials).to receive(:configured?).and_return(false)
      login_as(user)

      get "/gathers/#{gather.id}"

      expect(response.body).not_to include('gather-push-toggle')
    end
  end
end
