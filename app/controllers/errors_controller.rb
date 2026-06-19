# frozen_string_literal: true

class ErrorsController < ApplicationController
  layout 'errors'

  def show
    code = status_code.to_i
    respond_to do |format|
      format.html do
        # Render explicit path; if missing, fall back inline
        render "errors/#{code}", status: code
      rescue ActionView::MissingTemplate
        render inline: "<h1>#{code} Error</h1>", status: code
      end
      format.any { head code }
    end
  end

  private

  def status_code
    params[:code] || 500
  end
end
