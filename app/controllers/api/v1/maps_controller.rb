class Api::V1::MapsController < Api::V1::BaseController
  def index
    render json: { maps: gather_maps }
  end

  private

  def gather_maps
    Map.classic.basic.map do |m|
      {
        id: m.id,
        name: m.name,
        category_id: m.category_id
      }
    end
  end
end