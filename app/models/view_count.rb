# == Schema Information
#
# Table name: view_counts
#
#  id            :integer          not null, primary key
#  viewable_id   :integer
#  viewable_type :string(255)
#  ip_address    :string(255)
#  logged_in     :boolean
#  created_at    :date
#

class ViewCount < ActiveRecord::Base
  belongs_to :viewable, :polymorphic => true
  validates_uniqueness_of :ip_address, :scope => [ :viewable_id, :viewable_type ]
end
