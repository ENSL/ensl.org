class CustomUrlsController < ApplicationController
  def administrate
  end

  def create

  end

  def show
    custom_url = CustomUrl.find_by_name(params[:name])
    @article = custom_url.article
    raise AccessError unless @article.can_show? cuser
    @article.read_by! cuser if cuser
    render 'articles/show'
  end

  def update
  end

  def destroy
  end
end
