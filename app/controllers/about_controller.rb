class AboutController < ApplicationController
  def staff
  end

  def adminpanel
    raise AccessError unless cuser and @cuser.admin?
  end

  def statistics
  end
end
