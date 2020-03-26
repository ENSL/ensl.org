# == Schema Information
#
# Table name: view_counts
#
#  id            :integer          not null, primary key
#  ip_address    :string(255)
#  logged_in     :boolean
#  viewable_type :string(255)
#  created_at    :date
#  viewable_id   :integer
#
# Indexes
#
#  index_view_counts_on_viewable_type_and_viewable_id  (viewable_type,viewable_id)
#

class ViewCount < ActiveRecord::Base
  belongs_to :viewable, :polymorphic => true, :optional => true
  validates_uniqueness_of :ip_address, :scope => [ :viewable_id, :viewable_type ]
end
