module Api
  module V1
    class SalaryRecordsController < ApplicationController
      before_action :set_employee, only: [ :create ]
      before_action :set_salary_record, only: [ :update ]

      def create
        record = @employee.salary_records.new(salary_record_params)
        if record.save
          render json: { salary_record: serialize(record) }, status: :created
        else
          render_errors(record)
        end
      end

      # Edit a salary record's breakdown (add/update/remove components).
      def update
        if @salary_record.update(salary_record_params)
          render json: { salary_record: serialize(@salary_record) }
        else
          render_errors(@salary_record)
        end
      end

      private

      def set_employee
        @employee = Employee.find(params[:employee_id])
      rescue ActiveRecord::RecordNotFound
        render json: { errors: [ "Employee not found" ] }, status: :not_found
      end

      def set_salary_record
        @salary_record = SalaryRecord.find(params[:id])
      rescue ActiveRecord::RecordNotFound
        render json: { errors: [ "Salary record not found" ] }, status: :not_found
      end

      def serialize(record)
        Api::V1::SalaryRecordSerializer.call(record, include_components: true)
      end

      def render_errors(record)
        render json: { errors: record.errors.messages.transform_values(&:first) }, status: :unprocessable_content
      end

      def salary_record_params
        params.require(:salary_record).permit(
          :amount, :currency, :frequency, :effective_date,
          salary_components_attributes: [ :id, :name, :kind, :amount, :position, :_destroy ]
        )
      end
    end
  end
end
