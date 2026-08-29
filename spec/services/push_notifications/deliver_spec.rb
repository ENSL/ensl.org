# frozen_string_literal: true

require 'rails_helper'

RSpec.describe PushNotifications::Deliver do
  let(:user) { create(:user) }
  let!(:subscription) do
    user.push_subscriptions.create!(
      endpoint: 'https://push.example.com/subscription/abc123',
      p256dh_key: 'public-key',
      auth_key: 'auth-secret'
    )
  end
  let(:payload) { { title: 'Gather', body: 'Starting' } }

  def with_vapid_keys
    allow(WebPushCredentials).to receive_messages(configured?: true, public_key: 'public', private_key: 'private')
    yield
  end

  it 'does nothing without VAPID credentials' do
    allow(WebPushCredentials).to receive(:configured?).and_return(false)
    allow(WebPush).to receive(:payload_send)

    expect(described_class.call(user_ids: [user.id], payload: payload)).to eq(0)
    expect(WebPush).not_to have_received(:payload_send)
  end

  it 'sends the payload to each subscription' do
    allow(WebPush).to receive(:payload_send)

    delivered = with_vapid_keys { described_class.call(user_ids: [user.id], payload: payload) }

    expect(delivered).to eq(1)
    expect(WebPush).to have_received(:payload_send)
      .with(hash_including(endpoint: subscription.endpoint, message: payload.to_json))
  end

  it 'drops subscriptions the push service reports as expired' do
    response = instance_double(Net::HTTPGone, inspect: '410', body: '')
    allow(WebPush).to receive(:payload_send).and_raise(WebPush::ExpiredSubscription.new(response, 'push.example.com'))

    delivered = with_vapid_keys { described_class.call(user_ids: [user.id], payload: payload) }

    expect(delivered).to eq(0)
    expect(PushSubscription.exists?(subscription.id)).to be false
  end
end
