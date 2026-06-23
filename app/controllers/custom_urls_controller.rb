# frozen_string_literal: true

class CustomUrlsController < ApplicationController
  respond_to :html, :json
  responders :flash

  before_action :require_admin!, except: :show
  before_action :set_custom_url, only: %i[update destroy]
  before_action :load_administrate_page, only: %i[administrate create]

  def administrate; end

  def create
    @custom_url.assign_attributes(custom_url_params)

    if @custom_url.save
      respond_with @custom_url, location: custom_urls_url
    else
      render :administrate, status: :unprocessable_entity
    end
  end

  def show
    custom_url = CustomUrl.find_by!(name: params[:name])
    @article = custom_url.visible_article_for!(cuser)

    @article.mark_as_read! for: cuser if cuser
    render 'articles/show'
  end

  def update
    if @custom_url.update(custom_url_params)
      render json: {
        status: 200,
        message: t(:custom_urls_update),
        obj: { name: @custom_url.name, title: @custom_url.article&.title }
      }, status: :ok
    else
      render json: {
        status: 422,
        message: "#{t(:custom_urls_update_failed)}\n * #{@custom_url.errors.full_messages.join("\n * ")}",
        errors: @custom_url.errors.full_messages
      }, status: :unprocessable_entity
    end
  end

  def destroy
    @custom_url.destroy

    respond_to do |format|
      format.json do
        render json: {
          status: 200,
          message: t(:custom_urls_destroy, name: @custom_url.name)
        }, status: :ok
      end
      format.html do
        redirect_to custom_urls_url, notice: t(:custom_urls_destroy, name: @custom_url.name)
      end
    end
  end

  private

  def require_admin!
    raise AccessError unless cuser&.admin?
  end

  def set_custom_url
    @custom_url = CustomUrl.find(params[:id])
  end

  def custom_url_params
    params.require(:custom_url).permit(:name, :article_id)
  end

  def load_administrate_page
    @custom_urls = CustomUrl.includes(:article).order(:name)
    @custom_url ||= CustomUrl.new
    @articles_for_select = Article.order(:title).pluck(:title, :id)
  end
end
