# == Schema Information
#
# Table name: locks
#
#  id            :integer          not null, primary key
#  lockable_type :string(255)
#  created_at    :datetime
#  updated_at    :datetime
#  lockable_id   :integer
#
# Indexes
#
#  index_locks_on_lockable_id_and_lockable_type  (lockable_id,lockable_type)
#

class Lock < ActiveRecord::Base
  include Extra
  belongs_to :lockable, :polymorphic => true, :optional => true

  def can_create? cuser
    cuser and cuser.admin?
  end

  def can_destroy? cuser
    cuser and cuser.admin?
  end

  def self.params(params, cuser)
    params.require(:lock).permit(:lockable_type, :lockable_id)
  end
end
