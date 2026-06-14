# == Schema Information
#
# Table name: messages
#
#  id             :integer          not null, primary key
#  recipient_type :string(255)
#  sender_type    :string(255)
#  text           :text(65535)
#  text_parsed    :text(65535)
#  title          :string(255)
#  created_at     :datetime
#  updated_at     :datetime
#  recipient_id   :integer
#  sender_id      :integer
#
# Indexes
#
#  index_messages_on_recipient_id_and_recipient_type  (recipient_id,recipient_type)
#  index_messages_on_sender_id_and_sender_type        (sender_id,sender_type)
#

require 'rails_helper'

describe Message do
  let!(:user) { create :user }

  before do
    allow(Notifications).to receive(:pm)
  end

  describe 'create' do
    let(:message) { build :message }

    it 'creates a new message' do
      expect(message.valid?).to eq(true)
      expect do
        message.save!
      end.to change(Message, :count).by(1)
    end
  end

  describe 'Permissions' do
    let(:message) { Message.new }

    describe 'can_create?' do
      it 'returns false for nil user' do
        expect(message.can_create?(nil)).to be_falsey
      end

      it 'returns true for user' do
        expect(message.can_create?(user)).to be_truthy
      end

      it 'returns false if user is banned' do
        create :ban, :mute, user: user
        expect(message.can_create?(user)).to be_falsey
      end
    end

    describe 'can_show?' do
      let!(:message) { create :message }

      it 'returns false for nil user' do
        expect(message.can_show?(nil)).to be_falsey
      end

      it 'returns true if sender' do
        expect(message.can_show?(message.sender)).to be_truthy
      end

      it 'returns true if receiver' do
        expect(message.can_show?(message.recipient)).to be_truthy
      end

      it 'returns false if neither sender nor receiver' do
        expect(message.can_show?(user)).to be_falsey
      end
    end
  end

  describe 'XSS protection' do
    let(:recipient) { create(:user) }

    it 'leaves text_parsed unchanged when text is nil' do
      message = Message.new(sender: user, recipient: recipient, title: 'Test message', text: nil)

      expect { message.parse_text }.not_to change(message, :text_parsed)
    end

    it 'strips script tags from BBCode text' do
      message = Message.new(
        sender: user,
        recipient: recipient,
        title: 'Test message',
        text: '[b]bold[/b]<script>alert("xss")</script>'
      )

      message.save!

      expect(message.text_parsed).not_to include('<script>')
      expect(message.text_parsed).not_to include('alert')
      expect(message.text_parsed).to include('<strong>bold</strong>')
    end

    it 'strips iframe tags from text' do
      message = Message.new(
        sender: user,
        recipient: recipient,
        title: 'Test message',
        text: '[i]text[/i]<iframe src="evil.com"></iframe>'
      )

      message.save!

      expect(message.text_parsed).not_to include('<iframe')
    end

    it 'strips event handlers from text' do
      message = Message.new(
        sender: user,
        recipient: recipient,
        title: 'Test message',
        text: '[b]text[/b]<img src=x onerror="alert(1)">'
      )

      message.save!

      expect(message.text_parsed).not_to include('onerror')
      expect(message.text_parsed).not_to include('<img')
    end
  end

  describe '#thread' do
    it 'returns only system messages for the same recipient when sent by System' do
      recipient = create(:user)
      system_message = described_class.create!(recipient: recipient, sender_type: 'System', title: 'System',
                                               text: 'body')
      described_class.create!(recipient: recipient, sender_type: 'System', title: 'Other', text: 'body')
      described_class.create!(recipient: create(:user), sender_type: 'System', title: 'Ignored', text: 'body')

      expect(system_message.thread).to all(have_attributes(recipient_id: recipient.id, sender_type: 'System'))
    end

    it 'returns both directions of a user conversation' do
      recipient = create(:user)
      sent = create(:message, sender: user, recipient: recipient)
      received = create(:message, sender: recipient, recipient: user)
      create(:message)

      expect(sent.thread.map(&:id)).to contain_exactly(sent.id, received.id)
    end
  end

  describe '#send_notifications' do
    it 'notifies an opted-in user recipient' do
      recipient = create(:user)
      message = build(:message, sender: user, recipient: recipient)

      message.send_notifications

      expect(Notifications).to have_received(:pm).with(recipient, message)
    end

    it 'does not notify a user recipient who opted out' do
      recipient = create(:user)
      recipient.profile.update!(notify_pms: false)
      message = build(:message, sender: user, recipient: recipient)

      message.send_notifications

      expect(Notifications).not_to have_received(:pm).with(recipient, message)
    end

    it 'notifies only opted-in group users' do
      group = create(:group)
      subscribed_user = create(:user)
      muted_user = create(:user)
      muted_user.profile.update!(notify_pms: false)
      message = build(:message, sender: user, recipient: group)

      allow(group).to receive(:users).and_return([subscribed_user, muted_user])

      message.send_notifications

      expect(Notifications).to have_received(:pm).with(subscribed_user, message)
      expect(Notifications).not_to have_received(:pm).with(muted_user, message)
    end

    it 'notifies only opted-in team members' do
      team = create(:team)
      subscribed_user = create(:user)
      muted_user = create(:user)
      muted_user.profile.update!(notify_pms: false)
      message = build(:message, sender: user, recipient: team)
      active_teamers = [double(user: subscribed_user), double(user: muted_user)]

      allow(team).to receive_message_chain(:teamers, :active).and_return(active_teamers)

      message.send_notifications

      expect(Notifications).to have_received(:pm).with(subscribed_user, message)
      expect(Notifications).not_to have_received(:pm).with(muted_user, message)
    end

    it 'does nothing for unsupported recipient types' do
      message = build(:message, sender: user, recipient: nil)

      expect { message.send_notifications }.not_to raise_error
      expect(Notifications).not_to have_received(:pm)
    end
  end
end
