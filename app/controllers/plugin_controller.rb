# frozen_string_literal: true

class PluginController < ApplicationController
  # Most logic should be in here no in AMXX
  # Use JSON?

  def user
    render_out User.plugin_response(steamid: params[:id], channel: params[:ch])
  end

  def render_out(out)
    @text = out.join("\r")
    render layout: false
  end
end
