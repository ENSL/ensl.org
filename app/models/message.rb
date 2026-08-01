# frozen_string_literal: true

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

class Message < ApplicationRecord
  include Extra

  # attr_protected :id, :created_at, :updated_at
  attr_accessor :sender_raw

  validates :title, length: { in: 1..100 }
  validates :text, length: { in: 1..65_000 }

  scope :ordered, -> { order('created_at DESC') }

  belongs_to :sender, polymorphic: true, optional: true
  belongs_to :recipient, polymorphic: true, optional: true

  before_save :parse_text
  after_create :send_notifications

  acts_as_readable on: :created_at

  def to_s
    title
  end

  def thread
    if sender_type == 'System'
      Message.where(recipient_id: recipient.id, sender_type: 'System')
    else
      Message.find_by_sql [
        '(SELECT `messages`.* FROM `messages` WHERE `messages`.`sender_id` = ? ' \
        "AND `messages`.`sender_type` = 'User' AND `messages`.`recipient_id` = ?) " \
        'UNION ' \
        '(SELECT `messages`.* FROM `messages` WHERE `messages`.`sender_id` = ? ' \
        "AND `messages`.`sender_type` = 'User' AND `messages`.`recipient_id` = ?) " \
        'ORDER BY id',
        sender.id, recipient.id, recipient.id, sender.id
      ]
    end
  end

  def parse_text
    return unless text

    self.text_parsed = bbcode_to_html(text)
  end

  def send_notifications
    if recipient.instance_of?(User)
      Notifications.pm recipient, self if recipient.profile.notify_pms
    elsif recipient.instance_of?(Group)
      recipient.users.each do |u|
        Notifications.pm u, self if u.profile.notify_pms
      end
    elsif recipient.instance_of?(Team)
      recipient.teamers.active.each do |teamer|
        Notifications.pm teamer.user, self if teamer.user.profile.notify_pms
      end
    end
  end

  def can_show?(cuser)
    cuser and (cuser.received_messages.include?(self) or cuser.sent_messages.include?(self))
  end

  def can_create?(cuser)
    cuser and !cuser.banned?(Ban::TYPE_MUTE)
  end

  def self.recipient_for(recipient_type, recipient_id)
    case recipient_type
    when 'User'
      User.find(recipient_id)
    when 'Team'
      Team.find(recipient_id)
    when 'Group'
      Group.find(recipient_id)
    else
      raise Error, 'Illegible recipient'
    end
  end

  def sender_for(cuser)
    sender_raw == '' ? cuser : cuser.active_teams.find(sender_raw)
  end

  def self.params(params, _cuser)
    params.require(:message).permit(:recipient_type, :sender_type, :title, :text, :recipient_id, :sender_id,
                                    :sender_raw)
  end
end
