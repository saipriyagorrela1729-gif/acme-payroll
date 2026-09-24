require "rails_helper"

RSpec.describe "Api::V1::Sessions", type: :request do
  let(:json_headers) { { "Content-Type" => "application/json" } }

  describe "POST /api/v1/session" do
    it "returns a token for valid credentials" do
      user = create(:user, email: "hr@acme.example", password: "password123")

      post "/api/v1/session",
           params: { email: "hr@acme.example", password: "password123" }.to_json,
           headers: json_headers

      expect(response).to have_http_status(:ok)
      expect(json["token"]).to eq(user.api_token)
      expect(json["email"]).to eq("hr@acme.example")
    end

    it "rejects invalid credentials" do
      create(:user, email: "hr@acme.example", password: "password123")

      post "/api/v1/session",
           params: { email: "hr@acme.example", password: "wrong" }.to_json,
           headers: json_headers

      expect(response).to have_http_status(:unauthorized)
    end
  end

  describe "DELETE /api/v1/session" do
    it "rotates the token so the old one stops working" do
      user = create(:user)
      old_token = user.api_token

      delete "/api/v1/session", headers: auth_headers(user)

      expect(response).to have_http_status(:no_content)
      expect(user.reload.api_token).not_to eq(old_token)
    end
  end
end
