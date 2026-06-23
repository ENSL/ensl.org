# frozen_string_literal: true

class AboutController < ApplicationController
  before_action :require_admin!, only: :adminpanel

  def staff; end

  def adminpanel
    @first_directory = Directory.first
    @root_directory = Directory.find(Directory::ROOT) if @first_directory
  end

  def statistics; end

  private

  def require_admin!
    raise AccessError unless cuser&.admin?
  end
end
