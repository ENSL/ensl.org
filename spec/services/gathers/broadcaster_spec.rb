require 'rails_helper'

describe Gathers::Broadcaster do
  describe '.call' do
    let(:gather) { create(:gather) }
    let(:user1) { create(:user) }
    let(:user2) { create(:user) }
    let(:gatherer1) { create(:gatherer, gather: gather, user: user1) }
    let(:gatherer2) { create(:gatherer, gather: gather, user: user2) }

    before do
      gatherer1
      gatherer2
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
      described_class.call(gather, skip_user_ids: [user1.id])

      # Should broadcast to guest and user2, but not user1
      expect(Turbo::StreamsChannel).to have_received(:broadcast_replace_to).at_least(2).times
    end

    it 'reloads the gather' do
      called_count = 0
      allow(gather).to receive(:reload) {
        called_count += 1
        gather
      }
      described_class.call(gather)
      expect(called_count).to be > 0
    end

    it 'bumps the gather version' do
      expect(gather).to receive(:bump_version!).and_call_original
      described_class.call(gather)
    end

    it 'accepts skip_user_ids as an array' do
      expect { described_class.call(gather, skip_user_ids: [user1.id, user2.id]) }
        .not_to raise_error
    end

    it 'compacts skip_user_ids' do
      expect { described_class.call(gather, skip_user_ids: [user1.id, nil, user2.id]) }
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
