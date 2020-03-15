# == Schema Information
#
# Table name: categories
#
#  id         :integer          not null, primary key
#  name       :string(255)
#  sort       :integer
#  created_at :datetime
#  updated_at :datetime
#  domain     :integer
#

class Category < ActiveRecord::Base
  include Extra

  MAIN = 1
  SPECIAL = 10
  INTERVIEWS = 11
  RULES = 61

  DOMAIN_NEWS = 0
  DOMAIN_ARTICLES = 1
  DOMAIN_ISSUES = 2
  DOMAIN_SITES = 3
  DOMAIN_FORUMS = 4
  DOMAIN_MOVIES = 5
  DOMAIN_GAMES = 6

  PER_PAGE = 3

  attr_protected :id, :updated_at, :created_at, :sort

  validates_length_of :name, :in => 1..30
  validate :validate_domain

  scope :ordered, -> { order("sort ASC, created_at DESC") }
  scope :domain, -> (domain) { where(domain: domain) }
  scope :nospecial, -> { where.not(name: 'Special') }
  scope :newest, -> { includes(:articles).order("articles.created_at DESC") }
  # scope :page, lambda { |page| {:limit => "#{(page-1)*PER_PAGE}, #{(page-1)*PER_PAGE+PER_PAGE}"} }
  scope :of_user, -> (user) { where("articles.user_id", user.id).includes(:articles) }

  has_many :articles, -> { order("created_at DESC") }
  has_many :issues, -> { order("created_at DESC") }
  has_many :forums, -> { order("forums.position") }
  has_many :movies
  has_many :maps
  has_many :gathers
  has_many :servers

  acts_as_reader

  def to_s
    name
  end

  def domains
    {DOMAIN_NEWS => 'News',
     DOMAIN_ARTICLES => 'Articles',
     DOMAIN_ISSUES => 'Issues',
     DOMAIN_SITES => "Sites",
     DOMAIN_FORUMS => "Forums",
     DOMAIN_MOVIES => "Movies",
     DOMAIN_GAMES => "Games"}
  end

  def validate_domain
    errors.add :domain, I18n.t(:invalid_domain) unless domains.include? domain
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
