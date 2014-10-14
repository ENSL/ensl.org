class GathererSerializer < ApplicationSerializer
  attributes :id

  has_one :user
end
