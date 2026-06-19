# frozen_string_literal: true

require 'rails_helper'

describe Gathers::Result do
  describe 'attributes' do
    it 'is a Struct' do
      expect(described_class.superclass).to eq(Struct)
    end

    it 'accepts keyword arguments' do
      result = described_class.new(gather: 'test', gatherer: 'test2')
      expect(result.gather).to eq('test')
      expect(result.gatherer).to eq('test2')
    end

    it 'has gather attribute' do
      gather = double('gather')
      result = described_class.new(gather: gather)
      expect(result.gather).to eq(gather)
    end

    it 'has gatherer attribute' do
      gatherer = double('gatherer')
      result = described_class.new(gatherer: gatherer)
      expect(result.gatherer).to eq(gatherer)
    end

    it 'has vote attribute' do
      vote = double('vote')
      result = described_class.new(vote: vote)
      expect(result.vote).to eq(vote)
    end

    it 'has error attribute' do
      error = StandardError.new('test error')
      result = described_class.new(error: error)
      expect(result.error).to eq(error)
    end

    it 'allows nil attributes' do
      result = described_class.new(gather: nil, gatherer: nil, vote: nil, error: nil)
      expect(result.gather).to be_nil
      expect(result.gatherer).to be_nil
      expect(result.vote).to be_nil
      expect(result.error).to be_nil
    end
  end

  describe '#success?' do
    context 'when error is nil' do
      it 'returns true' do
        result = described_class.new(error: nil)
        expect(result.success?).to be(true)
      end
    end

    context 'when error is present' do
      let(:error) { StandardError.new('Something went wrong') }

      it 'returns false' do
        result = described_class.new(error: error)
        expect(result.success?).to be(false)
      end
    end

    context 'with a custom error class' do
      let(:custom_error) { Exceptions::AccessError.new('Access denied') }

      it 'returns false' do
        result = described_class.new(error: custom_error)
        expect(result.success?).to be(false)
      end
    end
  end

  describe 'initialization' do
    it 'can be initialized without arguments' do
      result = described_class.new
      expect(result).to be_a(described_class)
    end

    it 'can be initialized with all attributes' do
      gather = double('gather')
      gatherer = double('gatherer')
      vote = double('vote')
      error = StandardError.new

      result = described_class.new(
        gather: gather,
        gatherer: gatherer,
        vote: vote,
        error: error
      )

      expect(result.gather).to eq(gather)
      expect(result.gatherer).to eq(gatherer)
      expect(result.vote).to eq(vote)
      expect(result.error).to eq(error)
    end

    it 'can be initialized with partial attributes' do
      gather = double('gather')
      result = described_class.new(gather: gather)
      expect(result.gather).to eq(gather)
      expect(result.error).to be_nil
    end
  end

  describe 'usage in services' do
    context 'successful operation' do
      let(:gather) { create(:gather) }
      let(:gatherer) { create(:gatherer, gather: gather) }

      it 'creates a successful result' do
        result = described_class.new(gather: gather, gatherer: gatherer)
        expect(result.success?).to be(true)
      end
    end

    context 'failed operation' do
      let(:gather) { create(:gather) }
      let(:error) { Exceptions::AccessError.new('Not allowed') }

      it 'creates a failed result' do
        result = described_class.new(gather: gather, error: error)
        expect(result.success?).to be(false)
      end
    end
  end

  describe 'with actual models' do
    it 'works with gather object' do
      gather = create(:gather)
      result = described_class.new(gather: gather)
      expect(result.gather.id).to eq(gather.id)
    end

    it 'works with gatherer object' do
      gatherer = create(:gatherer)
      result = described_class.new(gatherer: gatherer)
      expect(result.gatherer.id).to eq(gatherer.id)
    end

    it 'works with vote object' do
      vote = create(:vote)
      result = described_class.new(vote: vote)
      expect(result.vote.id).to eq(vote.id)
    end
  end

  describe 'attribute defaults' do
    it 'defaults to nil for all attributes' do
      result = described_class.new
      expect(result.gather).to be_nil
      expect(result.gatherer).to be_nil
      expect(result.vote).to be_nil
      expect(result.error).to be_nil
    end
  end
end
