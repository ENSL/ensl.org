# frozen_string_literal: true

class UsersController < ApplicationController
  include Authentication

  before_action :load_user, only: %i[show history popup agenda edit update destroy]
  respond_to :html, :js

  PAGES = %w[general favorites computer articles movies teams matches predictions comments].freeze

  def index
    @users = User.browse(
      search: params[:search],
      filter: params[:filter],
      ip_search: cuser&.admin?,
      page: params[:page]
    )
  end

  def show
    @page = 'general'
    respond_to do |format|
      format.js do
        @page = params[:page] if PAGES.include?(params[:page])
      end
      format.html {}
    end
  end

  def popup
    render layout: false
  end

  def agenda
    raise AccessError unless (@user == cuser) || cuser&.admin?

    @teamer = Teamer.new
    @teamer.user = @user
  end

  def history
    raise AccessError unless cuser&.admin?
  end

  def new
    return if already_logged_in?

    # Use cached OAuth-created user only for anonymous visitors.
    if session[:cached_user].present? && cuser.nil?
      @user = begin
        User.new(JSON.parse(session[:cached_user]))
      rescue StandardError
        nil
      end
      session.delete :cached_user
    end
    @user ||= User.new
    @user.profile = Profile.new
    @user.lastip = request.env['REMOTE_ADDR']
    @user.can_create? cuser
    @user.preformat
  end

  def edit
    raise AccessError unless @user.can_update? cuser
  end

  def create
    return if already_logged_in?

    user = User.build_for_registration(raw_params: params, actor: cuser, remote_ip: request.env['REMOTE_ADDR'])
    user.apply_steam_registration_profile!(session[:steam_registration_profile]) if session[:verified_steamid].present?

    raise AccessError unless user.can_create? cuser

    if user.register_with_preformat
      redirect_to action: :show, id: user.id
      save_session user
    else
      @user = user
      render :new
    end
  end

  def update
    raise AccessError unless @user.can_update? cuser

    if defined?(Rails) && Rails.configuration.x.respond_to?(:debug_prints) && Rails.configuration.x.debug_prints
      Rails.logger.debug(params.inspect)
    end

    if @user.update(@user.filtered_update_attributes(params, cuser))
      flash[:notice] = flash_action_message(:update, @user)
      redirect_back(fallback_location: user_path(@user))
    else
      flash[:error] = t('users.update.failure')
      render :edit
    end
  end

  def destroy
    raise AccessError unless @user.can_destroy? cuser

    @user.destroy
    redirect_to users_url
  end

  private

  def load_user
    @user = User.find(params[:id])
  end
end
