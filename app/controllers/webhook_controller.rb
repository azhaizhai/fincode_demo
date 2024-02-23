class WebhookController < ApplicationController
  skip_before_action :verify_authenticity_token

  def create
    render json: { receive: 0 }
  end
end