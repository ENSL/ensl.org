# frozen_string_literal: true

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

# Model for locks on lockable objects. Used to prevent multiple
# users from posting in locked threads, matches etc.
class Lock < ApplicationRecord
  include Extra
  belongs_to :lockable, polymorphic: true, optional: true

  def can_create?(cuser)
    cuser&.admin?
  end

  def can_destroy?(cuser)
    cuser&.admin?
  end

  def self.params(params, _cuser)
    params.require(:lock).permit(:lockable_type, :lockable_id)
  end
end
