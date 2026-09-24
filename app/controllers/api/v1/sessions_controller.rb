module Api
  module V1
    class SessionsController < ApplicationController
      skip_before_action :authenticate!, only: [ :create ]

      # POST /api/v1/session  { email, password } -> { token, email }
      def create
        user = User.authenticate(email: params[:email], password: params[:password])
        if user
          render json: { token: user.api_token, email: user.email }
        else
          render json: { errors: [ "Invalid email or password" ] }, status: :unauthorized
        end
      end

      # DELETE /api/v1/session  (rotates the token so the old one is invalid)
      def destroy
        current_user.regenerate_api_token!
        head :no_content
      end
    end
  end
end
