class TridsCallbackController < ApplicationController
  skip_before_action :verify_authenticity_token

  def create
    event = params["event"]

    case event
    when "3DSMethodFinished", "3DSMethodSkipped"
      secure_auth_response = RestClient.put(
        "#{ENV["FINCODE_TEST_URL"]}/secure2/#{params["MD"]}",
        {
          param: params["param"]
        }.to_json,
        rest_client_header
      )
      raise "3ds auth error" if secure_auth_response.code != 200
      auth_detail = JSON.parse(secure_auth_response.body)

      @url = auth_detail["challenge_url"]
    when "AuthResultReady"
      if params["param"] == "Y"
        @payment = Payment.find_by(fincode_payment_access_id: params["MD"])

        secure_result_response = RestClient.get(
          "#{ENV["FINCODE_TEST_URL"]}/secure2/#{@payment.fincode_payment_access_id}",
          rest_client_header
        )
        raise "payment after 3ds error" if secure_result_response.code != 200
        secure_result = JSON.parse(secure_result_response.body)
        raise "3ds fail reason:#{secure_result["tds2_trans_result_reason"]}" if secure_result["tds2_trans_result"] != "Y"

        payment_after_3ds_response = RestClient.put(
          "#{ENV["FINCODE_TEST_URL"]}/payments/#{@payment.fincode_payment_id}/secure",
          {
            pay_type: "Card",
            access_id: @payment.fincode_payment_access_id
          }.to_json,
          rest_client_header
        )
        raise "payment after 3ds error" if payment_after_3ds_response.code != 200
        payment_detail = JSON.parse(payment_after_3ds_response.body)
        raise "invalid payment status:#{payment_detail["status"]}" if payment_detail["status"] != "CAPTURED"
        @payment.update!(status: :completed)
      else
        raise "3ds fail"
      end
    end
  end
end