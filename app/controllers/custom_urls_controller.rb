class CustomUrlsController < ApplicationController
  def administrate
    raise AccessError unless cuser && cuser.admin?
  end

  def create
    raise AccessError unless request.xhr?
  end

  def show
    custom_url = CustomUrl.find_by_name(params[:name])
    @article = custom_url.article
    raise AccessError unless @article.can_show? cuser
    @article.read_by! cuser if cuser
    render 'articles/show'
  end

  def update
    raise AccessError unless request.xhr?
  end

  def destroy
    raise AccessError unless request.xhr?
  end
end
