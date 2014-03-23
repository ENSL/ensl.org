class ViewCount < ActiveRecord::Base
  belongs_to :viewable, :polymorphic => true
  validates_uniqueness_of :ip_address, :scope => [ :viewable_id, :viewable_type ]
end
