# == Schema Information
#
# Table name: messages
#
#  id             :integer          not null, primary key
#  sender_type    :string(255)
#  sender_id      :integer
#  recipient_type :string(255)
#  recipient_id   :integer
#  title          :string(255)
#  text           :text
#  created_at     :datetime
#  updated_at     :datetime
#  text_parsed    :text
#

require "rails_helper"

describe Message do
  let!(:user) { create :user }

  describe "create" do
    let(:message) { build :message }

    it "creates a new message" do
      expect(message.valid?).to eq(true)
      expect do
        message.save!
      end.to change(Message, :count).by(1)
    end
  end

  describe "Permissions" do
    let(:message) { Message.new }

    describe "can_create?" do
      it "returns true for user" do
        expect(message.can_create?(user)).to be_truthy
      end

      it "returns false if user is banned" do
        create :ban, :mute, user: user
        expect(message.can_create?(user)).to be_falsey
      end
    end

    describe "can_show?" do
      let!(:message) { create :message }

      it "returns true if sender" do
        expect(message.can_show?(message.sender)).to be_truthy
      end

      it "returns true if receiver" do
        expect(message.can_show?(message.recipient)).to be_truthy
      end

      it "returns false if neither sender nor receiver" do
        expect(message.can_show?(user)).to be_falsey
      end
    end
  end
end
