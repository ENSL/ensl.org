class CustomUrl < ActiveRecord::Base
  belongs_to :article
  attr_accessible :name

  validates :name,
            length: {in: 2..10},
            uniqueness: true,
            format: /\A[a-z\-]{2,10}\Z/
end
