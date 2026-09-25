module Api
  module V1
    class SalaryRecordsController < ApplicationController
      before_action :set_employee, only: [ :create ]
      before_action :set_salary_record, only: [ :update ]

      def create
        record = @employee.salary_records.new(salary_record_params)
        carry_over_breakdown(record) if record.salary_components.empty?

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

      # A new salary revision (e.g. a raise) keeps the previous CTC structure,
      # scaled so the earning components still sum to the new gross. Without this
      # the breakdown would silently disappear when a revision is recorded.
      def carry_over_breakdown(record)
        # Query the DB so the (unsaved) new record is never treated as "previous".
        previous = @employee.salary_records.order(effective_date: :desc, id: :desc).first
        return unless previous&.salary_components&.any?

        new_gross = record.amount.to_d
        old_gross = previous.gross_earnings
        ratio = old_gross.zero? ? 0 : new_gross / old_gross

        components = previous.salary_components.map do |component|
          {
            name: component.name,
            kind: component.kind,
            amount: (component.amount.to_d * ratio).round(2),
            position: component.position
          }
        end

        # Absorb rounding into the last earning so earnings sum exactly to the gross.
        earnings = components.select { |component| component[:kind] == "earning" }
        if earnings.any?
          earnings.last[:amount] += (new_gross - earnings.sum { |component| component[:amount] })
        end

        components.each { |attrs| record.salary_components.build(attrs) }
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
