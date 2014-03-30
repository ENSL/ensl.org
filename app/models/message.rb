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

class Message < ActiveRecord::Base
  include Extra

  attr_protected :id, :created_at, :updated_at
  attr_accessor :sender_raw

  validates_length_of :title, :in => 1..100
  validates_length_of :text, :in => 1..65000

  scope :ordered, :order => "created_at DESC"
  scope :read_by,
    lambda { |user| {:include => :readings, :conditions => ["readings.user_id = ?", user.id]} }
  scope :unread_by,
    lambda { |user| {
    :joins => "LEFT JOIN readings ON readable_type = 'Message' AND readable_id = messages.id AND readings.user_id = #{user.id}",
    :conditions => "readings.user_id IS NULL"} }

  belongs_to :sender, :polymorphic => true
  belongs_to :recipient, :polymorphic => true

  before_save :parse_text
  after_create :send_notifications

  acts_as_readable

  def to_s
    title
  end

  def thread
    Message.find_by_sql ["
                         (SELECT `messages`.* FROM `messages` WHERE `messages`.`sender_id` = ? AND `messages`.`sender_type` = 'User' AND `messages`.`recipient_id` = ?)
                         UNION
                         (SELECT `messages`.* FROM `messages` WHERE `messages`.`sender_id` = ? AND `messages`.`sender_type` = 'User' AND `messages`.`recipient_id` = ?)
                         ORDER BY id", sender.id, recipient.id, recipient.id, sender.id]
  end

  def parse_text
    if self.text
      self.text_parsed = bbcode_to_html(self.text)
    end
  end

  def send_notifications
    if recipient.instance_of?(User)
      if recipient.profile.notify_pms
        Notifications.pm recipient, self
      end
    elsif recipient.instance_of?(Group)
      recipient.users.each do |u|
        if u.profile.notify_pms
          Notifications.pm u, self
        end
      end
    elsif recipient.instance_of?(Team)
      recipient.teamers.active.each do |teamer|
        if teamer.user.profile.notify_pms
          Notifications.pm teamer.user, self
        end
      end
    end
  end

  def can_show? cuser
    cuser and (cuser.received_messages.include?(self) or cuser.sent_messages.include?(self))
  end

  def can_create? cuser
    cuser and !cuser.banned?(Ban::TYPE_MUTE)
  end
end
