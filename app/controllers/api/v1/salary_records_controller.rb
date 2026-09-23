module Api
  module V1
    class SalaryRecordsController < ApplicationController
      before_action :set_employee

      def create
        record = @employee.salary_records.new(salary_record_params)
        if record.save
          render json: { salary_record: Api::V1::SalaryRecordSerializer.call(record) }, status: :created
        else
          render json: { errors: record.errors.messages.transform_values(&:first) }, status: :unprocessable_content
        end
      end

      private

      def set_employee
        @employee = Employee.find(params[:employee_id])
      rescue ActiveRecord::RecordNotFound
        render json: { errors: [ "Employee not found" ] }, status: :not_found
      end

      def salary_record_params
        params.require(:salary_record).permit(:amount, :currency, :frequency, :effective_date)
      end
    end
  end
end
