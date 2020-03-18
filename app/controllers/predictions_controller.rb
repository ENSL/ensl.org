class PredictionsController < ApplicationController
  def create
    @prediction = Prediction.new(Prediction.params(params, cuser))
    @prediction.user = cuser
    raise AccessError unless @prediction.can_create? cuser

    if @prediction.save
      flash[:notice] = t(:predictions_create)
    else
      flash[:error] = @prediction.errors.full_messages.to_s
    end

    redirect_to @prediction.match
  end
end
