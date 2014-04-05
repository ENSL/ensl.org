# == Schema Information
#
# Table name: issues
#
#  id          :integer          not null, primary key
#  title       :string(255)
#  status      :integer
#  assigned_id :integer
#  category_id :integer
#  text        :text
#  author_id   :integer
#  created_at  :datetime
#  updated_at  :datetime
#  solution    :text
#  text_parsed :text
#

require File.join(Rails.root, 'vendor', 'plugins', 'acts-as-readable', 'init.rb')

class Issue < ActiveRecord::Base
  include Extra
  
  STATUS_OPEN = 0
  STATUS_SOLVED = 1
  STATUS_REJECTED = 2

  attr_accessor :assigned_name
  attr_protected :id, :created_at, :updated_at

  has_many :comments, :as => :commentable
  belongs_to :category
  belongs_to :author, :class_name => "User"
  belongs_to :assigned, :class_name => "User"

  scope :unread_by,
    lambda { |user| {
    :joins => "LEFT JOIN readings ON readable_type = 'Issue' AND readable_id = issues.id AND readings.user_id = #{user.id}",
    :conditions => "readings.user_id IS NULL"} }
  scope :with_status, lambda { |s| { :conditions => {:status => s}} }

  validates_length_of :title, :in => 1..50
  validates_length_of :text, :in => 1..65000
  validate :validate_status

  before_validation :init_variables, :if => Proc.new{|issue| issue.new_record?}
  before_save :parse_text
  after_save :remove_readings

  acts_as_readable

  def to_s
    title
  end

  def status_s
    statuses[status]
  end

  def statuses
    {STATUS_OPEN => "Open", STATUS_SOLVED => "Solved", STATUS_REJECTED => "Rejected"}
  end

  def color
    if status == STATUS_SOLVED
      "green"
    elsif status == STATUS_OPEN
      "yellow"
    elsif status == STATUS_REJECTED
      "red"
    end
  end

  def init_variables
    self.assigned = User.find_by_username(assigned_name) if assigned_name
    self.status = STATUS_OPEN unless status
  end

  def validate_status
    errors.add :status, I18n.t(:invalid_status) unless statuses.include? status
  end

  def parse_text
    if self.text
      self.text_parsed = bbcode_to_html(self.text)
    end
  end

  def solution_formatted
    bbcode_to_html(solution)
  end

  def remove_readings
    if status_changed? and status == STATUS_SOLVED
      Reading.delete_all ["readable_type = 'Issue' AND readable_id = ?", self.id]
    end
  end

  def can_show? cuser
    cuser and !cuser.nil? and ((author == cuser) or cuser.admin?)
  end

  def can_create? cuser, params = {}
    Verification.contain params, [:title, :category_id, :text]
  end

  def can_update? cuser
    cuser and cuser.admin?
  end

  def can_destroy? cuser
    cuser and cuser.admin?
  end
end
