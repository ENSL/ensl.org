# frozen_string_literal: true

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

class ViewCount < ApplicationRecord
  belongs_to :viewable, polymorphic: true, optional: true
  validates :ip_address, uniqueness: { scope: %i[viewable_id viewable_type] }
end
