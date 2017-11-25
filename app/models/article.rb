# == Schema Information
#
# Table name: articles
#
#  id          :integer          not null, primary key
#  title       :string(255)
#  status      :integer          not null
#  category_id :integer
#  text        :text(16777215)
#  user_id     :integer
#  created_at  :datetime
#  updated_at  :datetime
#  version     :integer
#  text_parsed :text(16777215)
#  text_coding :integer          default(0), not null
#

require File.join(Rails.root, 'vendor', 'plugins', 'has_view_count', 'init.rb')

class Article < ActiveRecord::Base
  include Exceptions
  include Extra

  STATUS_PUBLISHED = 0
  STATUS_DRAFT = 1

  RULES = 1044
  HISTORY = 401
  HOF = 402
  SPONSORS = 403
  LINKS = 404
  COMPETITIVE = 405
  PLUGIN = 426
  EXTRA = 428
  SB_RULES = 450
  G_RULES = 464
  COMPMOD = 998

  scope :recent, ->{ order(created_at: :desc).limit(8) }
  scope :with_comments, lambda {
    select("articles.*, COUNT(C.id) AS comment_num")
    .joins("LEFT JOIN comments C ON C.commentable_type = 'Article' AND C.commentable_id = articles.id")
    .group(:id)
  }
  scope :ordered, -> { order(created_at: :desc) }
  scope :limited, -> { limit(5) }
  scope :nodrafts, -> { where(status: STATUS_PUBLISHED) }
  scope :drafts, -> { where(status: STATUS_DRAFT) }
  scope :of_category, ->(cat){ where(category_id: cat) }

  scope :domain, lambda { |domain|
    includes(:category)
      .where(category_id: {category: { domain: domain}})
  }
  scope :articles, -> { domain Category::DOMAIN_ARTICLES }
  scope :onlynews, -> { domain Category::DOMAIN_NEWS }

  scope :nospecial, -> { where(category_id: Category::SPECIAL) }
  scope :interviews, -> { where(category_id: Category::INTERVIEWS) }

  belongs_to :user
  belongs_to :category
  has_many :comments, as: :commentable, order: 'created_at ASC', dependent: :destroy
  has_many :files, class_name: 'DataFile', order: 'created_at DESC', dependent: :destroy

  validates_length_of :title, :in => 1..50
  validates_length_of :text, :in => 1..16000000

  validates_presence_of :user, :category
  validate :validate_status

  before_validation :init_variables, :if => Proc.new{ |model| model.new_record? }
  before_save :format_text
  after_save :send_notifications
  after_destroy :remove_readings

  has_view_count
  acts_as_readable
  acts_as_versioned

  non_versioned_columns << 'category_id'
  non_versioned_columns << 'status'
  non_versioned_columns << 'user_id'

  def to_s
    title
  end

  def previous_article
    category.articles.nodrafts.where(["id < ?", self.id]).order(id: :desc).first
  end

  def next_article
    category.articles.nodrafts.where(["id > ?", self.id]).order(:id).first
  end

  def statuses
    {STATUS_PUBLISHED => "Published", STATUS_DRAFT => "Draft"}
  end

  def validate_status
    errors.add :status, 'Invalid status' unless statuses.include? status
  end

  def init_variables
    self.status = STATUS_DRAFT unless user.admin?
    self.text_coding = CODING_BBCODE if !user.admin? and text_coding = CODING_HTML
  end

  def format_text
    if text_coding == CODING_BBCODE
      self.text_parsed = bbcode_to_html(text)
    elsif text_coding == CODING_MARKDOWN
      self.text_parsed = BlueCloth.new(text).to_html
    end
  end

  def send_notifications
    if (new_record? or status_changed?) and status == STATUS_PUBLISHED
      case category.domain
      when Category::DOMAIN_NEWS
        Profile.includes(:user).all(conditions: "notify_news = 1").each do |p|
          Notifications.news p.user, self if p.user
        end
      when Category::DOMAIN_ARTICLES
        Profile.includes(:user).all(conditions: "notify_articles = 1").each do |p|
          Notifications.article p.user, self if p.user
        end
      end
    end
  end

  def remove_readings
    Reading.delete_all ["readable_type = 'Category' AND readable_id = ?", category_id]
  end

  def can_show? cuser
    status != STATUS_DRAFT or (cuser and (user == cuser or cuser.admin?))
  end

  def can_create? cuser
    cuser and !cuser.banned?(Ban::TYPE_MUTE)
  end

  def can_update? cuser, params = {}
    cuser and !cuser.banned?(Ban::TYPE_MUTE) and (cuser.admin? or (user == cuser and !params.keys.include? "status"))
  end

  def can_destroy? cuser
    cuser and cuser.admin?
  end
end
