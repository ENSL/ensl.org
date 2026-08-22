# frozen_string_literal: true

require 'rails_helper'

describe Gathers::Leave do
  let(:gather) { create(:gather) }
  let!(:gatherer) { create(:gatherer, gather: gather) }
  let(:user) { gatherer.user }

  before do
    allow(Gathers::Broadcaster).to receive(:call)
  end

  describe '.call' do
    it 'returns a Result' do
      result = described_class.call(actor: user, gatherer: gatherer)
      expect(result).to be_a(Gathers::Result)
    end

    it 'is successful when user owns the gatherer' do
      result = described_class.call(actor: user, gatherer: gatherer)
      expect(result.success?).to be(true)
    end

    it 'removes the gatherer' do
      expect do
        described_class.call(actor: user, gatherer: gatherer)
      end.to change(Gatherer, :count).by(-1)
    end

    it 'records who left the gather' do
      described_class.call(actor: user, gatherer: gatherer)

      activity = gather.activities.find_by!(key: 'gather.left')
      expect(activity.owner).to eq(user)
      expect(activity.recipient).to eq(user)
    end

    it 'broadcasts the change' do
      described_class.call(actor: user, gatherer: gatherer)
      expect(Gathers::Broadcaster).to have_received(:call).with(gather)
    end

    it 'includes the gather in the result' do
      result = described_class.call(actor: user, gatherer: gatherer)
      expect(result.gather).to eq(gather)
    end
  end

  describe 'access control' do
    let(:other_user) { create(:user) }

    it 'prevents other users from leaving the gatherer' do
      result = described_class.call(actor: other_user, gatherer: gatherer)
      expect(result.success?).to be(false)
      expect(result.error).to be_a(NameError)
    end

    it 'prevents nil actor from leaving' do
      result = described_class.call(actor: nil, gatherer: gatherer)
      expect(result.success?).to be(false)
    end

    it 'allows the owner to leave' do
      result = described_class.call(actor: user, gatherer: gatherer)
      expect(result.success?).to be(true)
    end
  end

  describe 'error handling' do
    it 'catches standard errors' do
      allow_any_instance_of(Gatherer).to receive(:can_destroy?).and_raise(StandardError.new('Validation error'))
      result = described_class.call(actor: user, gatherer: gatherer)
      expect(result.success?).to be(false)
      expect(result.error).to be_a(StandardError)
    end

    it 'includes error in result on failure' do
      allow_any_instance_of(Gatherer).to receive(:can_destroy?).and_return(false)
      allow_any_instance_of(Gatherer).to receive(:destroy!).and_raise(Exceptions::AccessError)
      result = described_class.call(actor: user, gatherer: gatherer)
      expect(result.error).to be_present
    end

    it 'includes gather in error result' do
      allow_any_instance_of(Gatherer).to receive(:can_destroy?).and_return(false)
      allow_any_instance_of(Gatherer).to receive(:destroy!).and_raise(Exceptions::AccessError)
      result = described_class.call(actor: user, gatherer: gatherer)
      expect(result.gather).to eq(gather)
    end
  end

  describe '#initialize' do
    it 'stores actor and gatherer' do
      service = described_class.new(actor: user, gatherer: gatherer)
      expect(service.instance_variable_get(:@actor)).to eq(user)
      expect(service.instance_variable_get(:@gatherer)).to eq(gatherer)
    end
  end

  describe 'gatherer removal' do
    it 'destroys the gatherer record' do
      id = gatherer.id
      described_class.call(actor: user, gatherer: gatherer)
      expect(Gatherer.find_by(id: id)).to be_nil
    end

    it 'removes from the correct gather' do
      result = described_class.call(actor: user, gatherer: gatherer)
      expect(result.gather).to eq(gather)
    end
  end

  context 'when gatherer belongs to different user' do
    let(:other_user) { create(:user) }
    let(:other_gatherer) { create(:gatherer, gather: gather, user: other_user) }

    it 'prevents leaving other users gatherer' do
      result = described_class.call(actor: user, gatherer: other_gatherer)
      expect(result.success?).to be(false)
    end
  end

  describe 'broadcasting on success' do
    it 'broadcasts only once' do
      described_class.call(actor: user, gatherer: gatherer)
      expect(Gathers::Broadcaster).to have_received(:call).once
    end

    it 'broadcasts the correct gather' do
      described_class.call(actor: user, gatherer: gatherer)
      expect(Gathers::Broadcaster).to have_received(:call).with(gather)
    end
  end
end
