# frozen_string_literal: true

class PasskeysController < ApplicationController
  before_action :load_user
  before_action :authorize_user!

  def options
    options = registration_service.options(user: @user)
    render json: options
  rescue Passkeys::Error => e
    render json: { error: e.message }, status: e.status
  end

  def create
    registration_service.create(user: @user, credential_params: credential_params)
    render json: { message: t(:passkey_registered) }
  rescue Passkeys::Error => e
    render json: { error: e.message }, status: e.status
  end

  def destroy
    credential = @user.passkey_credentials.find(params[:credential_id])
    credential.destroy!
    flash[:notice] = t(:passkey_removed)
    redirect_back fallback_location: edit_user_path(@user)
  end

  private

  def load_user
    @user = User.find(params[:id])
  end

  def authorize_user!
    raise AccessError unless cuser == @user
  end

  def credential_params
    permitted_webauthn_credential_params
  end

  def registration_service
    @registration_service ||= Passkeys::RegistrationService.new(session: session, request: request)
  end
end
