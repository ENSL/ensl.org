# frozen_string_literal: true

class RoundsController < ApplicationController
  SORT_COLUMNS = {
    'start' => 'start',
    'server' => 'server_id',
    'team1' => 'team1_id',
    'team2' => 'team2_id',
    'map' => 'map_name',
    'commander' => 'commander_id'
  }.freeze

  def index
    sort = SORT_COLUMNS[params['sort']]

    @rounds = Round.basic.paginate \
      order: sort,
      page: params[:page],
      per_page: 30

    return unless params[:ajax]

    render partial: 'list', layout: false
    nil
  end

  def show
    @round = Round.find(params[:id])
  end
end
