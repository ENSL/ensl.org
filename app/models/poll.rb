# frozen_string_literal: true

# == Schema Information
#
# Table name: polls
#
#  id         :integer          not null, primary key
#  end_date   :datetime
#  question   :string(255)
#  votes      :integer          default(0), not null
#  created_at :datetime
#  updated_at :datetime
#  user_id    :integer
#
# Indexes
#
#  index_polls_on_user_id  (user_id)
#

class Poll < ApplicationRecord
  include Extra

  scope :recent, -> { order(created_at: :desc, id: :desc) }

  # attr_protected :id, :updated_at, :created_at, :votes, :user_id

  validates :question, length: { in: 1..50 }
  # validates_datetime :end_date

  belongs_to :user, optional: true
  has_many :options, class_name: 'Option', dependent: :destroy
  has_many :real_votes, through: :options

  accepts_nested_attributes_for :options, allow_destroy: true

  validate :must_have_at_least_two_options

  def voted?(user)
    real_votes.where(user_id: user.id).count.positive?
  end

  def can_create?(cuser)
    cuser&.admin?
  end

  def can_update?(cuser)
    cuser&.admin?
  end

  def can_destroy?(cuser)
    cuser&.admin?
  end

  def self.params(params, _cuser)
    params.require(:poll).permit(:end_date, :question, options_attributes: %i[id option _destroy poll_id])
  end

  private

  def must_have_at_least_two_options
    valid_options = options.reject do |o|
      o.marked_for_destruction? || o.option.to_s.strip.empty?
    end

    return unless valid_options.size < 2

    errors.add(:base, 'Poll must have at least two options')
  end
end
