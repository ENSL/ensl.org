# frozen_string_literal: true

# == Schema Information
#
# Table name: custom_urls
#
#  id         :integer          not null, primary key
#  name       :string(255)
#  created_at :datetime         not null
#  updated_at :datetime         not null
#  article_id :integer
#
# Indexes
#
#  index_custom_urls_on_article_id  (article_id)
#  index_custom_urls_on_name        (name)
#

# FIXME: move this to a gem
class CustomUrl < ApplicationRecord
  MENU_LINKED_NAMES = %w[compmod halloffame rules tutorials].freeze

  belongs_to :article, optional: true
  # FIXME: attr_accessible :name

  before_validation :normalize_name
  before_destroy :ensure_not_menu_linked

  validates :name,
            length: { in: 2..10 },
            uniqueness: true,
            format: /\A[a-z0-9]+(?:[-_][a-z0-9]+)*\Z/

  validates :article_id,
            presence: true

  def visible_article_for!(user)
    raise ActiveRecord::RecordNotFound unless article
    raise Exceptions::AccessError unless article.can_show?(user)

    article
  end

  def menu_linked?
    MENU_LINKED_NAMES.include?(name)
  end

  def self.params(params)
    params.require(:custom_url).permit(:name, :article_id)
  end

  private

  def normalize_name
    return if name.blank?

    self.name = name.to_s.strip.downcase.parameterize
  end

  def ensure_not_menu_linked
    return unless menu_linked?

    errors.add(:base, I18n.t(:custom_urls_destroy_menu_linked, name: name))
    throw :abort
  end
end
