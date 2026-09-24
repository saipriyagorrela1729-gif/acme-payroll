class ApplicationController < ActionController::API
  # Every API request must present a valid HR token (see SessionsController).
  before_action :authenticate!

  private

  attr_reader :current_user

  def authenticate!
    token = request.headers["Authorization"].to_s.split(" ").last
    @current_user = User.find_by(api_token: token) if token.present?
    render json: { errors: [ "Unauthorized" ] }, status: :unauthorized unless @current_user
  end
end
