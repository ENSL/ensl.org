class GatherSerializer < ApplicationSerializer
  attributes :id, :status, :votes, :turn, :lastpick1, :lastpick2

  has_one :category
  has_many :gatherers
  has_many :gather_servers
  has_many :gather_maps
end
