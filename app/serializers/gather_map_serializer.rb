class GatherMapSerializer < ApplicationSerializer
  attributes :id, :votes

  has_one :map
end
