# == Schema Information
#
# Table name: shoutmsgs
#
#  id             :integer          not null, primary key
#  shoutable_type :string(255)
#  text           :string(255)
#  created_at     :datetime
#  updated_at     :datetime
#  shoutable_id   :integer
#  user_id        :integer
#
# Indexes
#
#  index_shoutmsgs_on_shoutable_type_and_shoutable_id  (shoutable_type,shoutable_id)
#  index_shoutmsgs_on_user_id                          (user_id)
#

class Shoutmsg < ActiveRecord::Base
  include Extra

  #attr_protected :id, :created_at, :updated_at, :user_id

  validates_length_of :text, :in => 1..100
  validates_presence_of :user

  belongs_to :user
  belongs_to :shoutable, :polymorphic => true


  scope :recent, -> { includes(:user).order("id DESC").limit(8) }
  scope :box, -> { where(shoutable_type: nil, shoutable_id: nil).limit(8) }
  scope :typebox, -> { where(shoutable_type: nil, shoutable_id: nil) }
  scope :last500, -> { includes(:user).order("id DESC").limit(500) }
  scope :of_object, -> (object, id) { where(shoutable_type: object, shoutable_id: id) }
  scope :ordered, -> { order("id") }

  def domain
    self[:shoutable_type] ? "shout_#{shoutable_type}_#{shoutable_id}" : "shoutbox"
  end

  def can_create? cuser
    cuser and !user.banned?(Ban::TYPE_MUTE) and cuser.verified?
  end

  def can_destroy? cuser
    cuser and cuser.admin?
  end

  def self.flood? cuser, type = nil, id = nil
    return false if self.of_object(type, id).count < 3
    self.of_object(type, id).all(:order => "created_at DESC", :limit => 10).each do |msg|
      return false if cuser != msg.user
    end
    return true
  end

  def self.params(params, cuser)
    params.require(:shoutmsg).permit(:shoutable_id, :shoutable_type, :text)
  end
end
