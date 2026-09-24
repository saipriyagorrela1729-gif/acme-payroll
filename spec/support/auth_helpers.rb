module AuthHelpers
  # Returns JSON + auth headers for a request spec. Creates an HR user by default.
  def auth_headers(user = nil)
    user ||= create(:user)
    {
      "Content-Type" => "application/json",
      "Authorization" => "Bearer #{user.api_token}"
    }
  end
end

RSpec.configure do |config|
  config.include AuthHelpers, type: :request
end
