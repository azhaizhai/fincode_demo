class ApplicationController < ActionController::Base

  private
  def rest_client_header
    {
      "Accept" => "*/*",
      "Authorization" => "BEARER #{ENV["FINCODE_PRIVATE_KEY"]}",
      "Tenant-Shop-Id" => "#{ENV["TENANT_ID"]}",
      "Content-Type" => "application/json"
    }
  end
end
