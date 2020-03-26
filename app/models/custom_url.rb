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
class CustomUrl < ActiveRecord::Base
  belongs_to :article, :optional => true
  # FIXME: attr_accessible :name

  validates :name,
            length: {in: 2..10},
            uniqueness: true,
            format: /\A[a-z]+([\-])?[a-z]+\Z/

  validates :article_id,
            presence: true

  def self.params(params, cuser)
    params.require(:custom_url).permit(:name, :article_id)
  end
end