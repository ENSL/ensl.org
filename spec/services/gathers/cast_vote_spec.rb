# frozen_string_literal: true

require 'rails_helper'

describe Gathers::CastVote do
  let(:gather) { create(:gather) }
  let(:gatherer) { create(:gatherer, gather: gather) }
  let(:voter) { gatherer.user }
  let(:votable) { create(:gatherer, gather: gather) }
  let(:vote_params) do
    {
      votable_id: votable.id,
      votable_type: 'Gatherer'
    }
  end

  before do
    allow(Gathers::Broadcaster).to receive(:call)
    gather.update!(status: Gather::STATE_VOTING)
  end

  describe '.call' do
    it 'returns a Result' do
      result = described_class.call(actor: voter, params: vote_params)
      expect(result).to be_a(Gathers::Result)
    end

    it 'creates a vote and returns success' do
      result = nil

      expect do
        result = described_class.call(actor: voter, params: vote_params)
      end.to change(Vote, :count).by(1)

      expect(result.success?).to be(true)
    end

    it 'assigns the actor as the vote user' do
      result = described_class.call(actor: voter, params: vote_params)
      expect(result.vote.user).to eq(voter)
    end

    it 'broadcasts the gather on success' do
      described_class.call(actor: voter, params: vote_params)
      expect(Gathers::Broadcaster).to have_received(:call).with(gather)
    end

    it 'includes the gather and vote in the result' do
      result = described_class.call(actor: voter, params: vote_params)
      expect(result.gather).to eq(gather)
      expect(result.vote).to be_a(Vote)
    end
  end

  describe 'access control' do
    it 'prevents nil actor from voting' do
      result = described_class.call(actor: nil, params: vote_params)
      expect(result.success?).to be(false)
    end

    it 'requires actor to be in the gather' do
      outsider = create(:user)
      result = described_class.call(actor: outsider, params: vote_params)
      expect(result.success?).to be(false)
    end

    it 'prevents voting when gather is not in voting state' do
      gather.update!(status: Gather::STATE_RUNNING)
      result = described_class.call(actor: voter, params: vote_params)
      expect(result.success?).to be(false)
    end
  end

  describe 'vote creation' do
    it 'sets the votable correctly' do
      result = described_class.call(actor: voter, params: vote_params)
      expect(result.vote.votable).to eq(votable)
    end
  end

  describe 'error handling' do
    it 'catches standard errors' do
      allow_any_instance_of(Vote).to receive(:save!).and_raise(StandardError.new('Database error'))
      result = described_class.call(actor: voter, params: vote_params)
      expect(result.success?).to be(false)
      expect(result.error).to be_a(StandardError)
    end

    it 'includes error in result on failure' do
      allow_any_instance_of(Vote).to receive(:can_create?).and_return(false)
      allow_any_instance_of(Vote).to receive(:save!).and_raise(Exceptions::AccessError)
      result = described_class.call(actor: voter, params: vote_params)
      expect(result.error).to be_present
    end

    it 'retries transient deadlock and succeeds' do
      call_count = 0
      allow_any_instance_of(Vote).to receive(:save!).and_wrap_original do |original, *args|
        call_count += 1
        raise ActiveRecord::Deadlocked if call_count == 1

        original.call(*args)
      end

      result = described_class.call(actor: voter, params: vote_params)

      expect(result.success?).to be(true)
      expect(call_count).to be >= 2
    end

    it 'returns graceful busy error when lock contention persists' do
      allow_any_instance_of(Vote).to receive(:save!).and_raise(ActiveRecord::LockWaitTimeout)

      result = described_class.call(actor: voter, params: vote_params)

      expect(result.success?).to be(false)
      expect(result.error.to_s).to match(/gather is busy|try again/i)
    end
  end

  describe '#initialize' do
    it 'stores actor and params' do
      service = described_class.new(actor: voter, params: vote_params)
      expect(service.instance_variable_get(:@actor)).to eq(voter)
      expect(service.instance_variable_get(:@params)).to eq(vote_params)
    end
  end
end
