# == Schema Information
#
# Table name: maps
#
#  id          :integer          not null, primary key
#  deleted     :boolean          default("0"), not null
#  download    :string(255)
#  name        :string(255)
#  picture     :string(255)
#  created_at  :datetime
#  updated_at  :datetime
#  category_id :integer
#

class Map < ActiveRecord::Base
  include Extra

  #attr_protected :id, :updated_at, :created_at, :deleted

  has_and_belongs_to_many :contests
  has_many :matches, -> (map){ unscope(:where).where("map1_id = :id OR map2_id = :id", id: map.id) }

  scope :basic, -> { where(deleted: false).order("name") }
  scope :with_name, -> (name) { where(name: name) }
  scope :classic, -> { where("name LIKE 'ns_%'") }
  scope :of_category, ->(category) { where(category_id: category.id) }

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

  def self.params(params, cuser)
    params.require(:map).permit(:name, :download, :picture, :category_id)
  end
end
