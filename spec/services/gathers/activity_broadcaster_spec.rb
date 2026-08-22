# frozen_string_literal: true

require 'rails_helper'

describe Gathers::ActivityBroadcaster do
  let(:gather) { create(:gather) }
  let(:user) { create(:user) }
  let(:activity) do
    gather.create_activity(key: 'gather.joined', owner: user, recipient: user)
  end

  before do
    allow(Turbo::StreamsChannel).to receive(:broadcast_append_to)
  end

  it 'appends the rendered event to the gather shout stream' do
    described_class.call(activity)

    stream = "shout_Gather_#{gather.id}"
    expect(Turbo::StreamsChannel).to have_received(:broadcast_append_to).with(
      stream,
      target: stream,
      html: include('joined the gather')
    )
  end

  it 'does not broadcast activities for another trackable type' do
    activity.update!(trackable: user)

    described_class.call(activity)

    expect(Turbo::StreamsChannel).not_to have_received(:broadcast_append_to)
  end

  it 'renders player substitutions with the admin and both players' do
    replacement = create(:user)
    substitution = gather.create_activity(
      key: 'gather.player_substituted',
      owner: user,
      recipient: replacement,
      parameters: { previous_player: 'OldPlayer' }
    )

    described_class.call(substitution)

    expect(Turbo::StreamsChannel).to have_received(:broadcast_append_to).with(
      anything,
      hash_including(html: include(user.to_s, 'replaced OldPlayer with', replacement.to_s))
    )
  end
end
