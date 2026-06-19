# frozen_string_literal: true

# == Schema Information
#
# Table name: groups
#
#  id         :integer          not null, primary key
#  name       :string(255)
#  created_at :datetime
#  updated_at :datetime
#  founder_id :integer
#
# Indexes
#
#  index_groups_on_founder_id  (founder_id)
#

# Group model for user groups such as Admins, Referees, Casters, etc.
class Group < ActiveRecord::Base
  include Extra

  ADMINS = 1
  REFEREES = 2
  MOVIES = 3
  DONORS = 4
  MOVIEMAKERS = 5
  CASTERS = 6
  CHAMPIONS = 7
  PREDICTORS = 8
  STAFF = 10
  GATHER_MODERATORS = 14
  CONTRIBUTORS = 16

  # All core system groups that are bound to app logic and cannot be deleted
  RESERVED_GROUP_IDS = [ADMINS, REFEREES, CASTERS, CHAMPIONS, DONORS, MOVIEMAKERS, MOVIES, PREDICTORS, STAFF,
                        GATHER_MODERATORS, CONTRIBUTORS].freeze
  # Protected groups cannot be destroyed
  PROTECTED_GROUP_IDS = RESERVED_GROUP_IDS

  GROUP_ROLE_MAPPING = {
    admins: ADMINS,
    referees: REFEREES,
    casters: CASTERS,
    gathermods: GATHER_MODERATORS,
    contributors: CONTRIBUTORS,
    predictors: PREDICTORS
  }.freeze

  validates :name, presence: true, length: { maximum: 20 }

  has_many :groupers, dependent: :destroy
  has_many :users, through: :groupers
  # Removed erroneous HABTM declaration that conflicted with `has_many :users, through: :groupers`

  belongs_to :founder, class_name: 'User', optional: true

  def to_s
    name
  end

  def can_create?(cuser)
    cuser&.admin? || false
  end

  def can_update?(cuser)
    cuser&.admin? || false
  end

  def can_destroy?(cuser)
    (cuser&.admin? || false) && !PROTECTED_GROUP_IDS.include?(id)
  end

  class << self
    # Returns all users belonging to the specified group role
    # @param role [Symbol] the group role (e.g., :admins, :referees)
    # @return [Array<User>] array of groupers (users) in the role
    def group_members(role)
      group_id = GROUP_ROLE_MAPPING[role]
      return [] unless group_id

      find_by(id: group_id)&.groupers&.valid_users || []
    end

    # Dynamically define group member retrieval methods
    %i[admins referees casters gathermods contributors predictors].each do |role|
      define_method(role) { group_members(role) }
    end

    # Returns combined array of staff members (admins, casters, referees, and extras)
    def staff
      all_staff = admins + casters + referees + extras
      all_staff.group_by(&:user_id).values.map(&:first)
    end

    # Returns extra staff (predictors and staff group members)
    def extras
      predictors_users = group_members(:predictors)
      staff_group = find_by(id: STAFF)
      staff_users = staff_group ? staff_group.groupers.valid_users : []
      all_extras = predictors_users + staff_users
      all_extras.group_by(&:user_id).values.map(&:first)
    end

    # Returns protected group IDs that cannot be destroyed
    def protected_groups
      PROTECTED_GROUP_IDS
    end

    # Returns all reserved/core system group IDs
    def reserved_groups
      RESERVED_GROUP_IDS
    end
  end

  def self.params(params, _cuser)
    params.require(:group).permit(:name)
  end
end
