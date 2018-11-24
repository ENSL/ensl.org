class CustomUrlsController < ApplicationController
  def administrate
    raise AccessError unless cuser && cuser.admin?
    @custom_urls = CustomUrl.all
    @custom_url = CustomUrl.new
  end

  def create
    administrate

    @custom_url.name = params[:custom_url][:name]
    @custom_url.article_id = params[:custom_url][:article_id].to_i

    if @custom_url.save
      flash[:notice] = "Created URL with name #{@custom_url.name}"
      redirect_to custom_urls_url
    else
      flash[:error] = 'Error creating URL!'
      render :administrate
    end
  end

  def show
    custom_url = CustomUrl.find_by_name(params[:name])
    raise ActiveRecord::RecordNotFound unless custom_url
    @article = custom_url.article
    raise AccessError unless @article.can_show? cuser
    @article.read_by! cuser if cuser
    render 'articles/show'
  end

  def update
    raise AccessError unless request.xhr?
    response = {}
    if cuser && cuser.admin?
      url = CustomUrl.find(params[:id]) rescue nil

      if url
        url.article_id = params[:custom_url][:article_id]
        url.name= params[:custom_url][:name]
        if url.save
          response[:status] = 200
          response[:message] = 'Successfully updated!'
          resobj = {name: url.name, title: url.article.title}
          response[:obj] = resobj
        else
          response[:status] = 400
          message = 'Update failed! Errors:'
          url.errors.full_messages.each do |error|
            message += "\n * " + error
          end

          response[:message] = message
        end
      else
        response[:status] = 404
        response[:message] = 'Error! No Custom URL with this id exists.'
      end
    else
      response[:status] = 403
      response[:message] = 'You are not allowed to do this!'
    end

    render json: response, status: response[:status]
  end

  def destroy
    raise AccessError unless request.xhr?
    response = {}
    if cuser && cuser.admin?
      url = CustomUrl.destroy(params[:id])
      response[:status] = 200
      response[:message] = "Successfully deleted url with name: #{url.name}!"
    else
      response[:status] = 403
      response[:message] = 'You are not allowed to do this!'
    end

    render json: response, status: response[:status]
  end
end
