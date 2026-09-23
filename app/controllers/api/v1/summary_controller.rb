module Api
  module V1
    class SummaryController < ApplicationController
      def show
        render json: { summary: PayrollStats.new.call }
      end
    end
  end
end
