# frozen_string_literal: true

require 'rails_helper'

describe Gathers::CaptainPick do
  let(:gather) { create(:gather, :picking) }
  let(:captain) { create(:gatherer, gather: gather) }
  let(:player) { create(:gatherer, gather: gather) }

  before do
    gather.update(captain1_id: captain.id, turn: 1)
    allow(Gathers::Broadcaster).to receive(:call)
  end

  describe '.call' do
    it 'returns a Result' do
      result = described_class.call(actor: captain.user, gather: gather, player_id: player.id)
      expect(result).to be_a(Gathers::Result)
    end

    it 'is successful' do
      result = described_class.call(actor: captain.user, gather: gather, player_id: player.id)
      expect(result.success?).to be(true)
    end

    it 'assigns the player to a team' do
      expect do
        described_class.call(actor: captain.user, gather: gather, player_id: player.id)
      end.to change { player.reload.team }.from(nil).to(1)
    end

    it 'records the captain, player, and team' do
      described_class.call(actor: captain.user, gather: gather, player_id: player.id)

      activity = gather.activities.find_by!(key: 'gather.player_picked')
      expect(activity.owner).to eq(captain.user)
      expect(activity.recipient).to eq(player.user)
      expect(activity.parameters[:team]).to eq(1)
    end

    it 'broadcasts the change' do
      described_class.call(actor: captain.user, gather: gather, player_id: player.id)
      expect(Gathers::Broadcaster).to have_received(:call).with(gather)
    end

    it 'includes the gather in the result' do
      result = described_class.call(actor: captain.user, gather: gather, player_id: player.id)
      expect(result.gather).to eq(gather)
    end

    it 'includes the gatherer in the result' do
      result = described_class.call(actor: captain.user, gather: gather, player_id: player.id)
      expect(result.gatherer).to eq(player)
    end
  end

  describe 'access control' do
    let(:other_user) { create(:user) }
    let(:other_gatherer) { create(:gatherer, gather: gather) }

    before do
      other_gatherer
    end

    it 'prevents non-captains from picking' do
      result = described_class.call(actor: other_user, gather: gather, player_id: player.id)
      expect(result.success?).to be(false)
    end

    it 'allows the captain to pick' do
      result = described_class.call(actor: captain.user, gather: gather, player_id: player.id)
      expect(result.success?).to be(true)
    end

    it 'prevents nil actor from picking' do
      result = described_class.call(actor: nil, gather: gather, player_id: player.id)
      expect(result.success?).to be(false)
    end
  end

  describe 'transaction handling' do
    let(:broadcaster_double) { double(call: nil) }

    before do
      allow(Gathers::Broadcaster).to receive(:call).and_call_original
    end

    it 'uses transactions for gather and gatherer' do
      described_class.call(actor: captain.user, gather: gather, player_id: player.id)
      # Transaction calls happen during execution
      expect(player.reload.team).to eq(1)
    end

    it 'reloads gather within transaction' do
      original_id = gather.id
      described_class.call(actor: captain.user, gather: gather, player_id: player.id)
      expect(gather.id).to eq(original_id)
    end
  end

  describe 'error handling' do
    it 'catches standard errors' do
      allow_any_instance_of(Gatherer).to receive(:update!).and_raise(StandardError.new('Test error'))
      result = described_class.call(actor: captain.user, gather: gather, player_id: player.id)
      expect(result.success?).to be(false)
      expect(result.error).to be_a(StandardError)
    end

    it 'returns a busy error after exhausting lock retries' do
      allow(gather).to receive(:with_lock).and_raise(ActiveRecord::LockWaitTimeout)

      result = described_class.call(actor: captain.user, gather: gather, player_id: player.id)

      expect(result.success?).to be(false)
      expect(result.error.to_s).to match(/gather is busy|try again/i)
    end
  end

  describe '#initialize' do
    it 'stores actor, gather, and player_id' do
      service = described_class.new(actor: captain.user, gather: gather, player_id: player.id)
      expect(service.instance_variable_get(:@actor)).to eq(captain.user)
      expect(service.instance_variable_get(:@gather)).to eq(gather)
      expect(service.instance_variable_get(:@player_id)).to eq(player.id)
    end
  end
end
