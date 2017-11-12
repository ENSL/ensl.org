class CustomUrl < ActiveRecord::Base
  belongs_to :article
  attr_accessible :name

  validates :name,
            length: {in: 2..10},
            uniqueness: true,
            format: /\A[a-z]+([\-])?[a-z]+\Z/

  validates :article_id,
            presence: true
end
