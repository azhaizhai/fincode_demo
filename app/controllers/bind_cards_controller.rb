class BindCardsController < ApplicationController
  skip_before_action :verify_authenticity_token

  def index
    response = RestClient.post("#{ENV["FINCODE_TEST_URL"]}/customers", {}.to_json, rest_client_header)
    raise "response error" if response.code != 200
    @fincode_customer_id = JSON.parse(response.body)["id"]
    CreditCard.create!(fincode_customer_id: @fincode_customer_id)
  end

  def create
    credit_card = CreditCard.find_by(fincode_customer_id: params["customer_id"])
    credit_card.fincode_credit_card_id = params["id"]
    credit_card.save!

    render json: { credit_card_id: credit_card.id }
  end
end