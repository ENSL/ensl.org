class GatherServerSerializer < ApplicationSerializer
  attributes :id, :votes

  has_one :server
end
