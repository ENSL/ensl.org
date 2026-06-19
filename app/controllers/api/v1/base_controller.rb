# frozen_string_literal: true

module Api
  module V1
    class BaseController < ActionController::Base
      # Use standard exception behavior but skip verification for JSON API requests
      protect_from_forgery with: :exception
      skip_before_action :verify_authenticity_token, if: -> { request.format.json? }

      respond_to :json
    end
  end
end
