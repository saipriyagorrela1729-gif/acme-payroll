module Api
  module V1
    class MetaController < ApplicationController
      def departments
        render json: { departments: Employee.distinct.order(:department).pluck(:department) }
      end

      def countries
        render json: { countries: Employee.distinct.order(:country).pluck(:country) }
      end
    end
  end
end
