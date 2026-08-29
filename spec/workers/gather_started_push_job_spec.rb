# frozen_string_literal: true

require 'rails_helper'

RSpec.describe GatherStartedPushJob do
  let(:gather) { create(:gather, :picking) }

  def gatherer_with_push(enabled)
    user = create(:user)
    user.profile.update!(notify_push_gather: enabled)
    gather.gatherers.create!(user: user)
    user
  end

  it 'pushes only to gather players who opted in' do
    opted_in = gatherer_with_push(true)
    gatherer_with_push(false)
    outsider = create(:user)
    outsider.profile.update!(notify_push_gather: true)

    allow(PushNotifications::Deliver).to receive(:call)

    described_class.new.perform(gather.id)

    expect(PushNotifications::Deliver).to have_received(:call)
      .with(hash_including(user_ids: [opted_in.id]))
  end

  it 'does nothing when the gather no longer exists' do
    allow(PushNotifications::Deliver).to receive(:call)

    described_class.new.perform(gather.id + 10_000)

    expect(PushNotifications::Deliver).not_to have_received(:call)
  end
end
