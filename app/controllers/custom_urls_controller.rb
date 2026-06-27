# frozen_string_literal: true

class CustomUrlsController < ApplicationController
  respond_to :html, :turbo_stream

  before_action :require_admin!, except: :show
  before_action :set_custom_url, only: %i[update destroy]
  before_action :load_administrate_page, only: %i[administrate create update]

  def administrate; end

  def create
    @custom_url.assign_attributes(CustomUrl.params(params))

    if @custom_url.save
      redirect_to custom_urls_url,
                  notice: t('flash.actions.create.notice', resource_name: CustomUrl.model_name.human)
    else
      render :administrate, status: :unprocessable_content
    end
  end

  def show
    custom_url = CustomUrl.find_by!(name: params[:name])
    @article = custom_url.visible_article_for!(cuser)

    @article.mark_as_read! for: cuser if cuser
    render 'articles/show'
  end

  def update
    success = @custom_url.update(CustomUrl.params(params))
    message = success ? t(:custom_urls_update) : @custom_url.errors.full_messages.to_sentence

    respond_to do |format|
      format.turbo_stream do
        flash.now[success ? :notice : :error] = message
        render :update, status: success ? :ok : :unprocessable_content
      end
      format.html { redirect_to custom_urls_url, flash: { (success ? :notice : :error) => message } }
    end
  end

  def destroy
    @destroyed = @custom_url.destroy
    message = if @destroyed
                t(:custom_urls_destroy,
                  name: @custom_url.name)
              else
                @custom_url.errors.full_messages.to_sentence
              end

    respond_to do |format|
      format.turbo_stream do
        flash.now[@destroyed ? :notice : :error] = message
        render :destroy, status: @destroyed ? :ok : :unprocessable_content
      end
      format.html { redirect_to custom_urls_url, flash: { (@destroyed ? :notice : :error) => message } }
    end
  end

  private

  def require_admin!
    raise AccessError unless cuser&.admin?
  end

  def set_custom_url
    @custom_url = CustomUrl.find(params[:id])
  end

  def load_administrate_page
    @custom_urls = CustomUrl.includes(:article).order(:name)
    @custom_url ||= CustomUrl.new
    @articles_for_select = Article.order(:title).pluck(:title, :id)
  end
end
