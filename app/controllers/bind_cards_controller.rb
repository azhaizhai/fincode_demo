class BindCardsController < ApplicationController
  skip_before_action :verify_authenticity_token

  def index
  end

  def create
    token = params.dig("list", "0", "token")
    raise "token blank" unless token.present?

    response = RestClient.post("#{ENV["FINCODE_TEST_URL"]}/customers", {}.to_json, rest_client_header)
    raise "create customer response error" if response.code != 200
    fincode_customer_id = JSON.parse(response.body)["id"]
    credit_card = CreditCard.create!(fincode_customer_id: fincode_customer_id)

    response = RestClient.post("#{ENV["FINCODE_TEST_URL"]}/customers/#{fincode_customer_id}/cards", {default_flag: "1", token: token}.to_json, rest_client_header)
    raise "bind card response error" if response.code != 200
    card_id = JSON.parse(response.body)["id"]

    credit_card.fincode_credit_card_id = card_id
    credit_card.save!

    render json: { credit_card_id: credit_card.id }
  end
end