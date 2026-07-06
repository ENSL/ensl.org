class RoundsController < ApplicationController
  def index
    sort = case params['sort']
           when "start" then "start"
           when "server" then "server_id"
           when "team1"  then "team1_id"
           when "team2" then "team2_id"
           when "map" then "map_name"
           when "commander" then "commander_id"
           end

    @rounds = Round.basic.paginate \
      order: sort,
      page: params[:page],
      per_page: 30

    if params[:ajax]
      render partial: 'list', layout: false
      return
    end
  end

  def show
    @round = Round.find(params[:id])
  end
end
