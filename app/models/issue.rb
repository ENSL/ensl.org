# frozen_string_literal: true

# == Schema Information
#
# Table name: issues
#
#  id          :integer          not null, primary key
#  solution    :text(65535)
#  status      :integer
#  text        :text(65535)
#  text_parsed :text(65535)
#  title       :string(255)
#  created_at  :datetime
#  updated_at  :datetime
#  assigned_id :integer
#  author_id   :integer
#  category_id :integer
#
# Indexes
#
#  index_issues_on_assigned_id  (assigned_id)
#  index_issues_on_author_id    (author_id)
#  index_issues_on_category_id  (category_id)
#

class Issue < ApplicationRecord
  include Extra

  STATUS_OPEN = 0
  STATUS_SOLVED = 1
  STATUS_REJECTED = 2

  CATEGORY_WEBSITE = 17
  CATEGORY_NSLPLUGIN = 20
  CATEGORY_LEAGUE = 22
  CATEGORY_GATHER = 54

  attr_accessor :assigned_name

  # attr_protected :id, :created_at, :updated_at

  has_many :comments, as: :commentable, dependent: :destroy
  belongs_to :category, optional: true
  belongs_to :author, class_name: 'User', optional: true
  belongs_to :assigned, class_name: 'User', optional: true

  # scope :unread_by,
  #  lambda { |user| {
  #  :joins => "LEFT JOIN readings ON readable_type = 'Issue' " \
  #            "AND readable_id = issues.id AND readings.user_id = #{user.id}",
  #  :conditions => "readings.user_id IS NULL"} }
  scope :with_status, ->(s) { where(status: s) }
  scope :visible_to, lambda { |cuser|
    qstring = 'category_id IN (?)'
    qstring += ' OR category_id IS NULL' if cuser&.admin?
    where(qstring, allowed_categories(cuser))
  }

  validates :title, length: { in: 1..50 }
  validates :text, length: { in: 1..65_000 }
  validate :validate_status

  before_validation :init_variables, if: proc(&:new_record?)
  before_save :parse_text

  acts_as_readable on: :created_at

  def to_s
    title
  end

  def status_s
    statuses[status]
  end

  def statuses
    { STATUS_OPEN => 'Open', STATUS_SOLVED => 'Solved', STATUS_REJECTED => 'Rejected' }
  end

  def color
    case status
    when STATUS_SOLVED
      'green'
    when STATUS_OPEN
      'yellow'
    when STATUS_REJECTED
      'red'
    end
  end

  def init_variables
    self.assigned = User.find_by(username: assigned_name) if assigned_name
    self.status = STATUS_OPEN unless status
  end

  def validate_status
    errors.add :status, I18n.t(:invalid_status) unless statuses.include? status
  end

  def parse_text
    return unless text

    self.text_parsed = bbcode_to_html(text)
  end

  def solution_formatted
    bbcode_to_html(solution)
  end

  def can_show?(cuser)
    return false unless cuser
    return true if cuser.admin?

    ((author == cuser) or Issue.allowed_categories(cuser).include?(category_id))
  end

  def can_create?(_cuser)
    true
  end

  def can_update?(cuser, params = {})
    return false unless cuser
    return true if cuser.admin?
    return false unless Issue.allowed_categories(cuser).include?(category_id)

    !(params.member?(:category_id) && (category_id.to_s != params[:category_id]))
  end

  def can_destroy?(cuser)
    cuser&.admin?
  end

  # STATIC METHODS

  def self.allowed_categories(cuser)
    allowed = []
    allowed << CATEGORY_GATHER if cuser.admin? || cuser.gather_moderator? # gather
    allowed << CATEGORY_WEBSITE if cuser.admin? # website
    allowed << CATEGORY_LEAGUE if cuser.admin? # league
    allowed << CATEGORY_NSLPLUGIN if cuser.admin? # ensl plugin
    allowed
  end

  def self.sort_column(param)
    case param
    when 'title' then 'title'
    when 'status' then 'status'
    when 'assigned' then 'assigned_id'
    when 'category' then 'category_id'
    else 'created_at DESC'
    end
  end

  def self.params(params, _cuser)
    params.require(:issue).permit(:solution, :status, :text, :title,
                                  :assigned_id, :author_id, :category_id)
  end
end
