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
