class Api::V1::GathersController < Api::V1::BaseController

  def create
    # gather = createFromParams
    #
    # unless gather
    #  render json: { errors: ['Invalid Data']}, status: :bad_request
    #   return
    # end

    render text: createFromParams.inspect
  end

  private

  def createFromParams
    @gan = params[:gather]
    unless checkAuth
      return nil
    end

    Gather.transaction do
      gather = Gather.create(category_id: 18, status: Gather::STATE_FINISHED, created_at: Time.zone.parse(@gan[:done][:time]) )


    end
  end

  def checkAuth
    params[:sign] == Digest::SHA2.hexdigest( @gan.to_json + ENV['APP_SECRET'])
  end
end