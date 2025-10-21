# app/controllers/api/sessions_controller.rb
class Api::V1::SessionsController < ApplicationController
  def me
    #Rails.logger.info "=== DEBUG: Request headers ==="
    #Rails.logger.info request.headers.env.select { |k, _| k.start_with?('HTTP_') }
    #Rails.logger.info "=== DEBUG: Cookies ==="
    #Rails.logger.info request.cookies
    #Rails.logger.info "=== DEBUG: Session ==="
    #Rails.logger.info session.to_hash

    if cuser
      render json: { signed_in: true, user: { id: cuser.id, email: cuser.email } }
    else
      render json: { signed_in: false }, status: :unauthorized
    end
  end
end
