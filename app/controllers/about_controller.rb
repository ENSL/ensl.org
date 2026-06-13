class AboutController < ApplicationController
  before_action :require_admin!, only: :adminpanel

  def staff
  end

  def adminpanel
  end

  def statistics
  end

  private

  def require_admin!
    raise AccessError unless cuser&.admin?
  end
end
