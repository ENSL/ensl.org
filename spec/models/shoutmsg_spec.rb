# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Shoutmsg, type: :model do
  let(:user) { create(:user) }

  describe 'validations' do
    it 'is valid with user and text within 1..100 chars' do
      shout = described_class.new(user: user, text: 'hello')
      expect(shout).to be_valid
    end

    it 'requires user' do
      shout = described_class.new(text: 'hello')
      expect(shout).not_to be_valid
      expect(shout.errors[:user]).to be_present
    end

    it 'requires text' do
      shout = described_class.new(user: user, text: '')
      expect(shout).not_to be_valid
      expect(shout.errors[:text]).to be_present
    end

    it 'rejects text longer than 100 chars' do
      shout = described_class.new(user: user, text: 'a' * 101)
      expect(shout).not_to be_valid
      expect(shout.errors[:text]).to be_present
    end
  end

  describe 'scopes' do
    let!(:gather) { create(:gather, :running) }

    it '.recent returns newest messages first with limit 8' do
      10.times { |n| create(:shoutmsg, text: "recent-#{n}") }

      result = described_class.recent
      expect(result.size).to eq(8)
      expect(result.map(&:id)).to eq(result.map(&:id).sort.reverse)
    end

    it '.box returns only global shoutbox messages and limits to 8' do
      10.times { |n| create(:shoutmsg, text: "box-main-#{n}") }
      3.times { |n| create(:shoutmsg, shoutable: gather, text: "box-gather-#{n}") }

      result = described_class.box
      expect(result.size).to eq(8)
      expect(result).to all(have_attributes(shoutable_type: nil, shoutable_id: nil))
    end

    it '.typebox returns all global shoutbox messages without 8-item limit' do
      10.times { |n| create(:shoutmsg, text: "typebox-main-#{n}") }
      2.times { |n| create(:shoutmsg, shoutable: gather, text: "typebox-gather-#{n}") }

      result = described_class.typebox
      expect(result.size).to eq(10)
      expect(result).to all(have_attributes(shoutable_type: nil, shoutable_id: nil))
    end

    it '.of_object returns messages for a specific shoutable object' do
      target = create(:gather, :running)
      other = create(:gather, :running)

      target_msg = create(:shoutmsg, shoutable: target, text: 'target')
      create(:shoutmsg, shoutable: other, text: 'other')
      create(:shoutmsg, text: 'main')

      result = described_class.of_object('Gather', target.id)
      expect(result).to contain_exactly(target_msg)
    end

    it '.ordered returns ascending id order' do
      a = create(:shoutmsg, text: 'ordered-a')
      b = create(:shoutmsg, text: 'ordered-b')
      c = create(:shoutmsg, text: 'ordered-c')

      result_ids = described_class.where(id: [a.id, b.id, c.id]).ordered.pluck(:id)
      expect(result_ids).to eq([a.id, b.id, c.id].sort)
    end

    it '.last500 relation has expected limit and descending order by id' do
      relation = described_class.last500
      expect(relation.limit_value).to eq(500)
      expect(relation.to_sql).to include('ORDER BY id DESC')
    end
  end

  describe '#domain' do
    it 'returns shoutbox for global messages' do
      shout = described_class.new(user: user, text: 'x')
      expect(shout.domain).to eq('shoutbox')
    end

    it 'returns shout_<Type>_<id> for object messages' do
      gather = create(:gather, :running)
      shout = described_class.new(user: user, shoutable: gather, text: 'x')
      expect(shout.domain).to eq("shout_Gather_#{gather.id}")
    end
  end

  describe 'permission helpers' do
    describe '#can_create?' do
      it 'returns false when current user is nil' do
        shout = described_class.new(user: user, text: 'x')
        expect(shout.can_create?(nil)).to be_falsey
      end

      it 'returns false when user is muted' do
        cuser = instance_double('User')
        allow(cuser).to receive(:banned?).with(Ban::TYPE_MUTE).and_return(true)
        allow(cuser).to receive(:verified?).and_return(true)

        shout = described_class.new(user: user, text: 'x')
        expect(shout.can_create?(cuser)).to be false
      end

      it 'returns false when user is not verified' do
        cuser = instance_double('User')
        allow(cuser).to receive(:banned?).with(Ban::TYPE_MUTE).and_return(false)
        allow(cuser).to receive(:verified?).and_return(false)

        shout = described_class.new(user: user, text: 'x')
        expect(shout.can_create?(cuser)).to be false
      end

      it 'returns true when user is not muted and verified' do
        cuser = instance_double('User')
        allow(cuser).to receive(:banned?).with(Ban::TYPE_MUTE).and_return(false)
        allow(cuser).to receive(:verified?).and_return(true)

        shout = described_class.new(user: user, text: 'x')
        expect(shout.can_create?(cuser)).to be true
      end
    end

    describe '#can_destroy?' do
      it 'returns true for admin users' do
        admin = create(:user, :admin)
        shout = described_class.new(user: user, text: 'x')
        expect(shout.can_destroy?(admin)).to be true
      end

      it 'returns false for non-admin users' do
        shout = described_class.new(user: user, text: 'x')
        expect(shout.can_destroy?(user)).to be false
      end

      it 'returns false when current user is nil' do
        shout = described_class.new(user: user, text: 'x')
        expect(shout.can_destroy?(nil)).to be_falsey
      end
    end
  end

  describe 'callbacks' do
    it 'normalizes emoji aliases before validation' do
      shout = described_class.new(user: user, text: ':smile:')
      allow(EmojiParser).to receive(:parse).with(':smile:').and_return('RAW_SMILE')

      shout.valid?

      expect(shout.text).to eq('RAW_SMILE')
    end
  end

  describe '#broadcast_shoutmsg' do
    let(:logger) { instance_double(Logger, info: true, error: true) }

    before do
      allow(Rails).to receive(:logger).and_return(logger)
    end

    it 'returns early when the shout cannot be reloaded' do
      shout = described_class.new(user: user, text: 'x')
      allow(shout).to receive(:id).and_return(101)
      allow(described_class).to receive(:find_by).with(id: 101).and_return(nil)

      expect(shout).not_to receive(:broadcast_prepend_to)
      expect(shout).not_to receive(:broadcast_append_to)
      expect { shout.send(:broadcast_shoutmsg) }.not_to raise_error
    end

    it 'prepends to shoutbox for global messages' do
      shout = build(:shoutmsg, user: user, text: 'global')
      allow(shout).to receive(:id).and_return(102)
      allow(described_class).to receive(:find_by).with(id: 102).and_return(shout)
      allow(User).to receive(:find_by).with(id: user.id).and_return(user)
      allow(ApplicationController).to receive(:render).and_return('<div>global</div>')

      expect(shout).to receive(:broadcast_prepend_to).with('shoutbox', target: 'shoutbox', html: '<div>global</div>')
      expect(shout).not_to receive(:broadcast_append_to)

      shout.send(:broadcast_shoutmsg)
    end

    it 'appends to shoutable domain for object messages' do
      gather = create(:gather, :running)
      shout = build(:shoutmsg, user: user, shoutable: gather, text: 'gather')
      allow(shout).to receive(:id).and_return(103)
      allow(described_class).to receive(:find_by).with(id: 103).and_return(shout)
      allow(User).to receive(:find_by).with(id: user.id).and_return(user)
      allow(ApplicationController).to receive(:render).and_return('<div>gather</div>')

      expect(shout).to receive(:broadcast_append_to).with(shout.domain, target: shout.domain, html: '<div>gather</div>')
      expect(shout).not_to receive(:broadcast_prepend_to)

      shout.send(:broadcast_shoutmsg)
    end

    it 'does not load a user when user_id is blank' do
      shout = described_class.new(text: 'no-user')
      allow(shout).to receive(:id).and_return(104)
      allow(described_class).to receive(:find_by).with(id: 104).and_return(shout)
      allow(ApplicationController).to receive(:render).and_return('<div>anon</div>')

      expect(User).not_to receive(:find_by)
      expect(shout).to receive(:broadcast_prepend_to).with('shoutbox', target: 'shoutbox', html: '<div>anon</div>')

      shout.send(:broadcast_shoutmsg)
    end

    it 'rescues and logs errors raised during rendering/broadcast' do
      shout = build(:shoutmsg, user: user, text: 'boom')
      allow(shout).to receive(:id).and_return(105)
      allow(described_class).to receive(:find_by).with(id: 105).and_return(shout)
      allow(User).to receive(:find_by).with(id: user.id).and_return(user)
      allow(ApplicationController).to receive(:render).and_raise(StandardError, 'render-failed')

      expect(logger).to receive(:error).with(/Shoutmsg broadcast failed: StandardError: render-failed/)
      expect { shout.send(:broadcast_shoutmsg) }.not_to raise_error
    end
  end

  describe '.flood?' do
    it 'returns false when fewer than three messages exist in the scope' do
      relation = double('relation')
      allow(described_class).to receive(:of_object).with('Gather', 42).and_return(relation)
      allow(relation).to receive(:count).and_return(2)

      expect(described_class.flood?(user, 'Gather', 42)).to be false
    end

    it 'returns true when recent messages are all from the same user' do
      relation = double('relation')
      msgs = Array.new(3) { instance_double(Shoutmsg, user: user) }
      allow(described_class).to receive(:of_object).with('Gather', 42).and_return(relation)
      allow(relation).to receive(:count).and_return(3)
      allow(relation).to receive(:all).and_return(msgs)

      expect(described_class.flood?(user, 'Gather', 42)).to be true
    end

    it 'returns false when at least one recent message is from another user' do
      other_user = create(:user)
      relation = double('relation')
      msgs = [
        instance_double(Shoutmsg, user: user),
        instance_double(Shoutmsg, user: other_user),
        instance_double(Shoutmsg, user: user)
      ]
      allow(described_class).to receive(:of_object).with('Gather', 42).and_return(relation)
      allow(relation).to receive(:count).and_return(3)
      allow(relation).to receive(:all).and_return(msgs)

      expect(described_class.flood?(user, 'Gather', 42)).to be false
    end
  end

  describe '.params' do
    it 'permits the expected shoutmsg params' do
      params = ActionController::Parameters.new(
        shoutmsg: { shoutable_id: 12, shoutable_type: 'Gather', text: 'hello', user_id: 999 }
      )

      permitted = described_class.params(params, user)
      expect(permitted[:shoutable_id]).to eq(12)
      expect(permitted[:shoutable_type]).to eq('Gather')
      expect(permitted[:text]).to eq('hello')
      expect(permitted).not_to have_key(:user_id)
    end

    it 'raises when :shoutmsg key is missing' do
      params = ActionController::Parameters.new({})
      expect { described_class.params(params, user) }.to raise_error(ActionController::ParameterMissing)
    end
  end
end
