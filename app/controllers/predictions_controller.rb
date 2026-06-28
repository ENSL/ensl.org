# frozen_string_literal: true

class PredictionsController < ApplicationController
  def create
    @prediction = Prediction.build_for_actor(params, cuser)
    raise AccessError unless @prediction.can_create? cuser

    save_and_flash(@prediction, notice: :predictions_create) { @prediction.save }
    redirect_to @prediction.match
  end
end
