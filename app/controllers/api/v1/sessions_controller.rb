# app/controllers/api/sessions_controller.rb
class Api::V1::SessionsController < ApplicationController
  def me
    if cuser
      render json: { signed_in: true, user: { id: cuser.id, email: cuser.email } }
    else
      render json: { signed_in: false }, status: :unauthorized
    end
  end
end
