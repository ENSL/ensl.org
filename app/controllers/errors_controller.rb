class ErrorsController < ApplicationController
  layout 'errors'

  def show
    render status_code.to_s, status: status_code
  end
 
  private
 
  def status_code
    params[:code] || 500
  end
end
