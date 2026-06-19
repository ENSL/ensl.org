# frozen_string_literal: true

require 'rails_helper'

describe Gathers::Kick do
  let(:gather) { create(:gather) }
  let!(:gatherer) { create(:gatherer, gather: gather) }

  before do
    allow(Gathers::Broadcaster).to receive(:call)
  end

  describe '.call' do
    context 'with admin actor' do
      let(:admin) { create(:user, :admin) }

      it 'returns a Result' do
        result = described_class.call(actor: admin, gatherer: gatherer)
        expect(result).to be_a(Gathers::Result)
      end

      it 'is successful' do
        result = described_class.call(actor: admin, gatherer: gatherer)
        expect(result.success?).to be(true)
      end

      it 'removes the gatherer' do
        expect do
          described_class.call(actor: admin, gatherer: gatherer)
        end.to change(Gatherer, :count).by(-1)
      end

      it 'broadcasts the change' do
        described_class.call(actor: admin, gatherer: gatherer)
        expect(Gathers::Broadcaster).to have_received(:call).with(gather)
      end

      it 'includes the gather in the result' do
        result = described_class.call(actor: admin, gatherer: gatherer)
        expect(result.gather).to eq(gather)
      end
    end

    context 'with gather_moderator actor' do
      let(:moderator) { create(:user) }

      before do
        group = create(:group, :gather_moderator)
        create(:grouper, user: moderator, group: group)
      end

      it 'is successful' do
        result = described_class.call(actor: moderator, gatherer: gatherer)
        expect(result.success?).to be(true)
      end

      it 'removes the gatherer' do
        expect do
          described_class.call(actor: moderator, gatherer: gatherer)
        end.to change(Gatherer, :count).by(-1)
      end
    end
  end

  describe 'access control' do
    let(:regular_user) { create(:user) }

    it 'prevents regular users from kicking' do
      result = described_class.call(actor: regular_user, gatherer: gatherer)
      expect(result.success?).to be(false)
      expect(result.error).to be_a(NameError)
    end

    it 'prevents nil actor from kicking' do
      result = described_class.call(actor: nil, gatherer: gatherer)
      expect(result.success?).to be(false)
      expect(result.error).to be_a(NameError)
    end

    it 'allows only admins and gather moderators' do
      other_user = create(:user)
      result = described_class.call(actor: other_user, gatherer: gatherer)
      expect(result.success?).to be(false)
    end
  end

  describe 'error handling' do
    let(:admin) { create(:user, :admin) }

    it 'catches standard errors' do
      allow_any_instance_of(Gatherer).to receive(:destroy!).and_raise(StandardError.new('Database error'))
      result = described_class.call(actor: admin, gatherer: gatherer)
      expect(result.success?).to be(false)
      expect(result.error).to be_a(StandardError)
    end

    it 'includes error in result on failure' do
      allow(admin).to receive(:admin?).and_return(false)
      allow(admin).to receive(:gather_moderator?).and_return(false)
      result = described_class.call(actor: admin, gatherer: gatherer)
      expect(result.error).to be_present
    end
  end

  describe '#initialize' do
    let(:admin) { create(:user, :admin) }

    it 'stores actor and gatherer' do
      service = described_class.new(actor: admin, gatherer: gatherer)
      expect(service.instance_variable_get(:@actor)).to eq(admin)
      expect(service.instance_variable_get(:@gatherer)).to eq(gatherer)
    end
  end

  describe 'gatherer removal' do
    let(:admin) { create(:user, :admin) }

    it 'destroys the gatherer record' do
      id = gatherer.id
      described_class.call(actor: admin, gatherer: gatherer)
      expect(Gatherer.find_by(id: id)).to be_nil
    end

    it 'removes from the correct gather' do
      result = described_class.call(actor: admin, gatherer: gatherer)
      expect(result.gather).to eq(gather)
    end
  end

  context 'when gatherer belongs to different gather' do
    let(:admin) { create(:user, :admin) }
    let(:other_gather) { create(:gather) }
    let(:other_gatherer) { create(:gatherer, gather: other_gather) }

    it 'still allows kicking' do
      result = described_class.call(actor: admin, gatherer: other_gatherer)
      expect(result.success?).to be(true)
      expect(result.gather).to eq(other_gather)
    end
  end

  describe 'result on error' do
    let(:regular_user) { create(:user) }

    it 'includes gatherer in error result' do
      result = described_class.call(actor: regular_user, gatherer: gatherer)
      expect(result.gatherer).to eq(gatherer)
    end

    it 'includes gather in error result' do
      result = described_class.call(actor: regular_user, gatherer: gatherer)
      expect(result.gather).to eq(gather)
    end
  end
end
