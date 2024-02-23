class CreditCardsController < ApplicationController
  skip_before_action :verify_authenticity_token

  def show
    @credit_card = CreditCard.find(params["id"])
  end

  def new_auth_payment
    @credit_card = CreditCard.find(params["id"])
  end

  def new_capture_payment
    @credit_card = CreditCard.find(params["id"])
  end

  def new_3ds_payment
    @credit_card = CreditCard.find(params["id"])
  end
end