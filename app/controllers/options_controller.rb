class OptionsController < ApplicationController
  before_action :get_poll, only: [:add, :create]
  before_action :get_option, only: [:edit, :update, :destroy]
  respond_to :html, :js

  # Renders a form fragment (typically via AJAX) to add a new option
  def add
    @option = @poll.options.build
    respond_to do |format|
      format.js   # renders options/add.js.erb if present
      format.html { render :new }
    end
  end

  def create
    @option = @poll.options.build(option_params)
    raise AccessError unless @poll.can_update?(cuser)

    if @option.save
      flash[:notice] = t(:option_created) rescue "Option created"
      respond_to do |format|
        format.html { redirect_to @poll }
        format.js
      end
    else
      respond_to do |format|
        format.html { render 'polls/edit' }
        format.js
      end
    end
  end

  def edit
    # edit template can be rendered as HTML or JS
  end

  def update
    raise AccessError unless @option.poll.can_update?(cuser)

    if @option.update(option_params)
      flash[:notice] = t(:option_updated) rescue "Option updated"
      respond_to do |format|
        format.html { redirect_to @option.poll }
        format.js
      end
    else
      render :edit
    end
  end

  def destroy
    raise AccessError unless @option.poll.can_update?(cuser)
    @option.destroy
    respond_to do |format|
      format.html { redirect_to polls_url }
      format.js
    end
  end

  private

  def get_poll
    @poll = Poll.find(params[:poll_id] || params[:id] || params.dig(:option, :poll_id))
  end

  def get_option
    @option = Option.find(params[:id])
  end

  def option_params
    params.require(:option).permit(:option, :votes, :_destroy)
  end
end
