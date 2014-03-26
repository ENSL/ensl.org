# == Schema Information
#
# Table name: locks
#
#  id            :integer          not null, primary key
#  lockable_id   :integer
#  lockable_type :string(255)
#  created_at    :datetime
#  updated_at    :datetime
#

class Lock < ActiveRecord::Base
  include Extra
  belongs_to :lockable, :polymorphic => true

  def can_create? cuser
    cuser and cuser.admin?
  end

  def can_destroy? cuser
    cuser and cuser.admin?
  end
end
