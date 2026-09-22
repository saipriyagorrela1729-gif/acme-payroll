require "rails_helper"

RSpec.describe "Api::V1::Health", type: :request do
  it "returns ok with a timestamp" do
    get "/api/v1/health"

    expect(response).to have_http_status(:ok)
    body = JSON.parse(response.body)
    expect(body["status"]).to eq("ok")
    expect(body["time"]).to be_present
  end
end
