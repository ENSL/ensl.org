# frozen_string_literal: true

# == Schema Information
#
# Table name: categories
#
#  id         :integer          not null, primary key
#  domain     :integer
#  name       :string(255)
#  sort       :integer
#  created_at :datetime
#  updated_at :datetime
#
# Indexes
#
#  index_categories_on_domain  (domain)
#  index_categories_on_sort    (sort)
#

class Category < ApplicationRecord
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

  # attr_protected :id, :updated_at, :created_at, :sort

  validates :name, length: { in: 1..30 }
  validate :validate_domain

  scope :ordered, -> { order('sort ASC, created_at DESC') }
  scope :domain, ->(domain) { where(domain: domain) }
  scope :nospecial, -> { where.not(name: 'Special') }
  # scope :page, lambda { |page| {:limit => "#{(page-1)*PER_PAGE}, #{(page-1)*PER_PAGE+PER_PAGE}"} }
  scope :of_user, ->(user) { where(articles: { user: user }).includes(:articles) }

  has_many :articles, -> { order('created_at DESC') }, inverse_of: :category, dependent: :nullify
  has_many :issues, -> { order('created_at DESC') }, inverse_of: :category, dependent: :nullify
  has_many :forums, -> { order('forums.position') }, inverse_of: :category, dependent: :nullify
  has_many :movies, dependent: :nullify
  has_many :maps, dependent: :nullify
  has_many :gathers, dependent: :nullify
  has_many :servers, dependent: :nullify

  acts_as_readable

  after_create :align_sort_with_id

  # Get movie size filter categories (Shorts, Full Length, etc.)
  def self.movie_size_categories
    where(domain: DOMAIN_MOVIES).pluck(:name).compact.uniq
  end

  def to_s
    name
  end

  def display_name
    "#{domains[domain]} - #{self}"
  end

  def domains
    { DOMAIN_NEWS => 'News',
      DOMAIN_ARTICLES => 'Articles',
      DOMAIN_ISSUES => 'Issues',
      DOMAIN_SITES => 'Sites',
      DOMAIN_FORUMS => 'Forums',
      DOMAIN_MOVIES => 'Movies',
      DOMAIN_GAMES => 'Games' }
  end

  def validate_domain
    errors.add :domain, I18n.t(:invalid_domain) unless domains.include? domain
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
    params.require(:category).permit(:name, :sort, :domain)
  end

  def self.options_for_select(relation = all)
    relation.map { |c| [c.display_name, c.id] }
  end

  private

  def align_sort_with_id
    return unless sort.blank? || sort.zero?

    update!(sort: id)
  end
end
