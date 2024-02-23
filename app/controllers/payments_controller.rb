class PaymentsController < ApplicationController
  skip_before_action :verify_authenticity_token

  def show
    @payment = Payment.find(params["id"])
  end

  def pre_3ds
    credit_card = CreditCard.find(params["credit_card_id"])
    @payment = Payment.create!(credit_card: credit_card, status: :pending, amount: params["amount"])
    create_payment_response = RestClient.post(
      "#{ENV["FINCODE_TEST_URL"]}/payments",
      {
        "pay_type" => "Card",
        "job_code" => "CAPTURE",
        "amount" => "#{@payment.amount}",
        "tds_type" => "2"
      }.to_json,
      rest_client_header
    )
    raise "create payment error" if create_payment_response.code != 200
    payment_detail = JSON.parse(create_payment_response.body)
    raise "invalid payment status:#{payment_detail["status"]}" if payment_detail["status"] != "UNPROCESSED"
    @payment.update!(fincode_payment_id: payment_detail["id"], fincode_payment_access_id: payment_detail["access_id"], status: :processing)
    
    capture_payment_response = RestClient.put(
      "#{ENV["FINCODE_TEST_URL"]}/payments/#{@payment.fincode_payment_id}",
      {
        pay_type: "Card",
        access_id: @payment.fincode_payment_access_id,
        customer_id: credit_card.fincode_customer_id,
        card_id: credit_card.fincode_credit_card_id,
        method: "1",
        tds2_ret_url: "https://jay-test.airhost.co/trids_callback"
      }.to_json,
      rest_client_header
    )
    raise "capture payment error" if capture_payment_response.code != 200
    payment_detail = JSON.parse(capture_payment_response.body)
    raise "invalid payment status:#{payment_detail["status"]}" if payment_detail["status"] != "AUTHENTICATED"
    @payment.update!(status: :authorized)

    @url = payment_detail["acs_url"]
  end

  def capture
    credit_card = CreditCard.find(params["credit_card_id"])
    @payment = Payment.create!(credit_card: credit_card, status: :pending, amount: params["amount"])
    create_payment_response = RestClient.post(
      "#{ENV["FINCODE_TEST_URL"]}/payments",
      {"pay_type" => "Card", "job_code" => "CAPTURE", "amount" => "#{@payment.amount}"}.to_json,
      rest_client_header
    )
    raise "create payment error" if create_payment_response.code != 200
    payment_detail = JSON.parse(create_payment_response.body)
    raise "invalid payment status:#{payment_detail["status"]}" if payment_detail["status"] != "UNPROCESSED"
    @payment.update!(fincode_payment_id: payment_detail["id"], fincode_payment_access_id: payment_detail["access_id"], status: :processing)

    capture_payment_response = RestClient.put(
      "#{ENV["FINCODE_TEST_URL"]}/payments/#{@payment.fincode_payment_id}",
      {
        pay_type: "Card",
        access_id: @payment.fincode_payment_access_id,
        customer_id: credit_card.fincode_customer_id,
        card_id: credit_card.fincode_credit_card_id,
        method: "1"
      }.to_json,
      rest_client_header
    )
    raise "capture payment error" if capture_payment_response.code != 200
    payment_detail = JSON.parse(capture_payment_response.body)
    raise "invalid payment status:#{payment_detail["status"]}" if payment_detail["status"] != "CAPTURED"
    @payment.update!(status: :completed)
  end

  def auth
    credit_card = CreditCard.find(params["credit_card_id"])
    @payment = Payment.create!(credit_card: credit_card, status: :pending, amount: params["amount"])
    create_payment_response = RestClient.post(
      "#{ENV["FINCODE_TEST_URL"]}/payments",
      {"pay_type" => "Card", "job_code" => "AUTH", "amount" => "#{@payment.amount}"}.to_json,
      rest_client_header
    )
    raise "create payment error" if create_payment_response.code != 200
    payment_detail = JSON.parse(create_payment_response.body)
    raise "invalid payment status:#{payment_detail["status"]}" if payment_detail["status"] != "UNPROCESSED"
    @payment.update!(fincode_payment_id: payment_detail["id"], fincode_payment_access_id: payment_detail["access_id"], status: :processing)

    auth_payment_response = RestClient.put(
      "#{ENV["FINCODE_TEST_URL"]}/payments/#{@payment.fincode_payment_id}",
      {
        pay_type: "Card",
        access_id: @payment.fincode_payment_access_id,
        customer_id: credit_card.fincode_customer_id,
        card_id: credit_card.fincode_credit_card_id,
        method: "1"
      }.to_json,
      rest_client_header
    )
    raise "auth payment error" if auth_payment_response.code != 200
    payment_detail = JSON.parse(auth_payment_response.body)
    raise "invalid payment status:#{payment_detail["status"]}" if payment_detail["status"] != "AUTHORIZED"
    @payment.update!(status: :authorized)
  end

  def capture_after_auth
    @payment = Payment.find(params["id"])
    raise "Invalid payment status: #{@payment.status}" unless @payment.authorized?
    capture_payment_response = RestClient.put(
      "#{ENV["FINCODE_TEST_URL"]}/payments/#{@payment.fincode_payment_id}/capture",
      {
        pay_type: "Card",
        access_id: @payment.fincode_payment_access_id
      }.to_json,
      rest_client_header
    )
    raise "capture payment error" if capture_payment_response.code != 200
    payment_detail = JSON.parse(capture_payment_response.body)
    raise "invalid payment status:#{payment_detail["status"]}" if payment_detail["status"] != "CAPTURED"
    @payment.update!(status: :completed)
  end

  def refund
    @payment = Payment.find(params["id"])
    amount = params["amount"].to_i
    raise "Refund amount must less than payment amount" if @payment.actual_amount < amount

    if @payment.actual_amount == amount
      cancel_payment_response = RestClient.put(
        "#{ENV["FINCODE_TEST_URL"]}/payments/#{@payment.fincode_payment_id}/cancel",
        {
          pay_type: "Card",
          access_id: @payment.fincode_payment_access_id
        }.to_json,
        rest_client_header
      )
      raise "create payment error" if cancel_payment_response.code != 200
      payment_detail = JSON.parse(cancel_payment_response.body)
      raise "invalid payment status:#{payment_detail["status"]}" if payment_detail["status"] != "CANCELED"
      @payment.update!(status: :voided)
    else
      if @payment.authorized?
        @payment.update!(amount: @payment.amount - amount)
        change_payment_response = RestClient.put(
          "#{ENV["FINCODE_TEST_URL"]}/payments/#{@payment.fincode_payment_id}/change",
          {
            pay_type: "Card",
            access_id: @payment.fincode_payment_access_id,
            job_code: "AUTH",
            amount: "#{ @payment.amount }"
          }.to_json,
          rest_client_header
        )
        raise "change payment error" if change_payment_response.code != 200
        payment_detail = JSON.parse(change_payment_response.body)
        raise "invalid payment status:#{payment_detail["status"]}" if payment_detail["status"] != "AUTHORIZED"
      else
        @refund = Refund.create!(payment: @payment, amount: amount, status: :processing)
        change_payment_response = RestClient.put(
          "#{ENV["FINCODE_TEST_URL"]}/payments/#{@payment.fincode_payment_id}/change",
          {
            pay_type: "Card",
            access_id: @payment.fincode_payment_access_id,
            job_code: "CAPTURE",
            amount: "#{ @payment.actual_amount - amount }"
          }.to_json,
          rest_client_header
        )
        raise "change payment error" if change_payment_response.code != 200
        payment_detail = JSON.parse(change_payment_response.body)
        raise "invalid payment status:#{payment_detail["status"]}" if payment_detail["status"] != "CAPTURED"
        @refund.update!(status: :completed)
      end
    end
  end
end