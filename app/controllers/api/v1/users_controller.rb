class Api::V1::UsersController < Api::V1::BaseController
  def index
    respond_with Api::V1::UsersCollection.as_json
  end
end