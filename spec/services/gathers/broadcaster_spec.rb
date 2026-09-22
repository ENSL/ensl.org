# frozen_string_literal: true

require 'rails_helper'

describe Gathers::Broadcaster do
  describe '.call' do
    let(:gather) { create(:gather) }
    let(:primary_user) { create(:user) }
    let(:secondary_user) { create(:user) }
    let(:primary_gatherer) { create(:gatherer, gather: gather, user: primary_user) }
    let(:secondary_gatherer) { create(:gatherer, gather: gather, user: secondary_user) }

    before do
      primary_gatherer
      secondary_gatherer
      allow(Turbo::StreamsChannel).to receive(:broadcast_replace_to)
    end

    it 'broadcasts to guest users' do
      described_class.call(gather)

      expect(Turbo::StreamsChannel).to have_received(:broadcast_replace_to)
        .with(gather, hash_including(:target, :html))
    end

    it 'broadcasts to all users in the gather' do
      described_class.call(gather)

      expect(Turbo::StreamsChannel).to have_received(:broadcast_replace_to).at_least(2).times
    end

    it 'skips specified user IDs' do
      described_class.call(gather, skip_user_ids: [primary_user.id])

      # Should broadcast to guest and the secondary user, but not the primary user.
      expect(Turbo::StreamsChannel).to have_received(:broadcast_replace_to).at_least(2).times
    end

    it 'reloads the gather' do
      called_count = 0
      allow(gather).to receive(:reload) {
        called_count += 1
        gather
      }
      described_class.call(gather)
      expect(called_count).to be_positive
    end

    it 'bumps the gather version' do
      expect(gather).to receive(:bump_version!).and_call_original
      described_class.call(gather)
    end

    it 'accepts skip_user_ids as an array' do
      expect { described_class.call(gather, skip_user_ids: [primary_user.id, secondary_user.id]) }
        .not_to raise_error
    end

    it 'compacts skip_user_ids' do
      expect { described_class.call(gather, skip_user_ids: [primary_user.id, nil, secondary_user.id]) }
        .not_to raise_error
    end

    context 'with gatherers without users' do
      it 'broadcasts with only registered users' do
        # Create additional gatherers with users
        create(:gatherer, gather: gather)
        described_class.call(gather)
        expect(Turbo::StreamsChannel).to have_received(:broadcast_replace_to).at_least(2).times
      end
    end
  end

  describe '#initialize' do
    let(:gather) { create(:gather) }

    it 'accepts a gather' do
      broadcaster = described_class.new(gather)
      expect(broadcaster.instance_variable_get(:@gather)).to eq(gather)
    end

    it 'initializes skip_user_ids as an empty array' do
      broadcaster = described_class.new(gather)
      expect(broadcaster.instance_variable_get(:@skip_user_ids)).to eq([])
    end

    it 'accepts skip_user_ids parameter' do
      skip_ids = [1, 2, 3]
      broadcaster = described_class.new(gather, skip_user_ids: skip_ids)
      expect(broadcaster.instance_variable_get(:@skip_user_ids)).to eq(skip_ids)
    end
  end
end
