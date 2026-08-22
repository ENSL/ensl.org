# frozen_string_literal: true

require 'rails_helper'

describe Gathers::Join do
  let(:gather) { create(:gather) }
  let(:user) { create(:user) }
  let(:join_params) do
    {
      gather_id: gather.id,
      user_id: user.id
    }
  end

  before do
    allow(Gathers::Broadcaster).to receive(:call)
    allow(Gathers::ActivityBroadcaster).to receive(:call)
  end

  describe '.call' do
    it 'returns a Result' do
      result = described_class.call(actor: user, params: join_params)
      expect(result).to be_a(Gathers::Result)
    end

    it 'is successful when join is valid' do
      result = described_class.call(actor: user, params: join_params)
      expect(result.success?).to be(true)
    end

    it 'creates a gatherer' do
      expect do
        described_class.call(actor: user, params: join_params)
      end.to change(Gatherer, :count).by(1)
    end

    it 'records who joined the gather' do
      described_class.call(actor: user, params: join_params)

      activity = gather.activities.find_by!(key: 'gather.joined')
      expect(activity.owner).to eq(user)
      expect(activity.recipient).to eq(user)
    end

    it 'broadcasts the join activity after it commits' do
      described_class.call(actor: user, params: join_params)

      expect(Gathers::ActivityBroadcaster).to have_received(:call).with(
        an_object_having_attributes(key: 'gather.joined', trackable: gather)
      )
    end

    it 'assigns the user to the gatherer' do
      result = described_class.call(actor: user, params: join_params)
      expect(result.gatherer.user).to eq(user)
    end

    it 'assigns the gather to the gatherer' do
      result = described_class.call(actor: user, params: join_params)
      expect(result.gatherer.gather).to eq(gather)
    end

    it 'broadcasts to other users' do
      described_class.call(actor: user, params: join_params)
      expect(Gathers::Broadcaster).to have_received(:call).with(gather, skip_user_ids: [user.id])
    end

    it 'includes the gather in the result' do
      result = described_class.call(actor: user, params: join_params)
      expect(result.gather).to eq(gather)
    end

    it 'includes the gatherer in the result' do
      result = described_class.call(actor: user, params: join_params)
      expect(result.gatherer).to be_a(Gatherer)
    end
  end

  describe 'access control' do
    it 'requires the actor to be the joining user' do
      other_user = create(:user)
      result = described_class.call(actor: other_user, params: join_params)
      expect(result.success?).to be(false)
    end

    it 'allows an admin to join another user by username' do
      admin = create(:user, :admin)
      result = described_class.call(
        actor: admin,
        params: { gather_id: gather.id, username: user.username, confirm: '1' }
      )

      expect(result.success?).to be(true)
      expect(result.gatherer.user).to eq(user)
    end

    it 'prevents an ordinary user from joining another user by username' do
      other_user = create(:user)
      result = described_class.call(
        actor: other_user,
        params: { gather_id: gather.id, username: user.username, confirm: '1' }
      )

      expect(result.success?).to be(false)
    end

    it 'prevents nil actor from joining' do
      result = described_class.call(actor: nil, params: join_params)
      expect(result.success?).to be(false)
    end

    it 'prevents duplicate joins' do
      described_class.call(actor: user, params: join_params)
      result = described_class.call(actor: user, params: join_params)
      expect(result.success?).to be(false)
    end
  end

  describe 'transaction handling' do
    it 'uses transactions for gather and gatherer' do
      expect(Gather).to receive(:transaction).and_call_original
      expect(Gatherer).to receive(:transaction).and_call_original
      described_class.call(actor: user, params: join_params)
    end

    it 'locks the gather during transaction' do
      expect_any_instance_of(Gather).to receive(:lock!).and_call_original
      described_class.call(actor: user, params: join_params)
    end
  end

  describe 'when the gather fills' do
    before do
      create_list(:gatherer, Gather::FULL - 1, gather: gather)
    end

    it 'records the final join before captain voting starts' do
      described_class.call(actor: user, params: join_params)

      expect(gather.activities.order(:id).last(2).map(&:key)).to eq(
        %w[gather.joined gather.voting_started]
      )
    end

    it 'broadcasts both final-join events in chronological order' do
      broadcast_keys = []
      allow(Gathers::ActivityBroadcaster).to receive(:call) { |activity| broadcast_keys << activity.key }

      described_class.call(actor: user, params: join_params)

      expect(broadcast_keys.last(2)).to eq(%w[gather.joined gather.voting_started])
    end
  end

  describe 'error handling' do
    it 'catches standard errors' do
      allow_any_instance_of(Gatherer).to receive(:can_create?).and_raise(StandardError.new('Test error'))
      result = described_class.call(actor: user, params: join_params)
      expect(result.success?).to be(false)
      expect(result.error).to be_a(StandardError)
    end

    it 'includes error in result on failure' do
      allow_any_instance_of(Gatherer).to receive(:can_create?).and_return(false)
      allow_any_instance_of(Gatherer).to receive(:save!).and_raise(Exceptions::AccessError)
      result = described_class.call(actor: user, params: join_params)
      expect(result.error).to be_present
    end

    it 'still includes gather in error result' do
      allow_any_instance_of(Gatherer).to receive(:save!).and_raise(StandardError.new('Error'))
      result = described_class.call(actor: user, params: join_params)
      expect(result.gather).to be_nil.or eq(gather)
    end
  end

  describe '#initialize' do
    it 'stores actor and params' do
      service = described_class.new(actor: user, params: join_params)
      expect(service.instance_variable_get(:@actor)).to eq(user)
      expect(service.instance_variable_get(:@params)).to eq(join_params)
    end
  end

  describe 'gatherer creation' do
    it 'creates a new gatherer with the provided params' do
      result = described_class.call(actor: user, params: join_params)
      expect(result.gatherer).to be_persisted
      expect(result.gatherer.user_id).to eq(user.id)
      expect(result.gatherer.gather_id).to eq(gather.id)
    end

    it 'creates gatherer without team assignment' do
      result = described_class.call(actor: user, params: join_params)
      expect(result.gatherer.team).to be_nil
    end
  end

  context 'when gather is full' do
    before do
      create_list(:gatherer, Gather::FULL, gather: gather)
    end

    it 'prevents self-joining' do
      result = described_class.call(actor: user, params: join_params)
      expect(result.success?).to be(false)
    end

    it 'prevents an admin from joining another user' do
      gather.update!(status: Gather::STATE_RUNNING)
      admin = create(:user, :admin)
      result = described_class.call(
        actor: admin,
        params: { gather_id: gather.id, username: user.username, confirm: '1' }
      )

      expect(result.success?).to be(false)
    end
  end
end
