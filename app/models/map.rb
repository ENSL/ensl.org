# == Schema Information
#
# Table name: maps
#
#  id          :integer          not null, primary key
#  name        :string(255)
#  download    :string(255)
#  created_at  :datetime
#  updated_at  :datetime
#  deleted     :boolean          default(FALSE), not null
#  picture     :string(255)
#  category_id :integer
#

class Map < ActiveRecord::Base
  include Extra

  attr_protected :id, :updated_at, :created_at, :deleted

  has_and_belongs_to_many :contests

  scope :basic, :conditions => {:deleted => false}, :order => "name"
  scope :with_name, lambda { |name| {:conditions => {:name => name}} }
  scope :classic, :conditions => "name LIKE 'ns_%'"
  scope :of_category,
    lambda { |category| {
    :conditions => {:category_id => category.id} }}

  validates_length_of :name, :maximum => 20
  validates_length_of :download, :maximum => 100

  mount_uploader :picture, MapUploader

  def to_s
    name
  end

  def destroy
    update_attribute :deleted, true
  end

  def can_create? cuser
    cuser and cuser.admin?
  end

  def can_update? cuser
    cuser and cuser.admin?
  end

  def can_destroy? cuser
    cuser and cuser.admin?
  end
end
