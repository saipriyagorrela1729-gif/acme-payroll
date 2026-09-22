require "csv"

module Api
  module V1
    class EmployeesController < ApplicationController
      before_action :set_employee, only: %i[show update destroy]

      def index
        relation = filtered_scope
        total_count = relation.count
        paginated = relation.offset(offset).limit(per_page)

        render json: {
          data: paginated.map { |employee| Api::V1::EmployeeSerializer.call(employee) },
          meta: {
            page: page,
            per_page: per_page,
            total_count: total_count,
            total_pages: (total_count.to_f / per_page).ceil
          }
        }
      end

      def show
        render json: { employee: Api::V1::EmployeeSerializer.call(@employee, include_history: true) }
      end

      def create
        employee = Employee.new(employee_params)
        if employee.save
          render json: { employee: Api::V1::EmployeeSerializer.call(employee) }, status: :created
        else
          render_errors(employee)
        end
      end

      def update
        if @employee.update(employee_params)
          render json: { employee: Api::V1::EmployeeSerializer.call(@employee) }
        else
          render_errors(@employee)
        end
      end

      def destroy
        @employee.destroy
        head :no_content
      end

      def export
        employees = Employee.includes(:salary_records).order(:name)
        csv = CSV.generate(headers: true) do |builder|
          builder << %w[
            name email job_title department country currency status hire_date
            salary_amount salary_frequency salary_effective_date
          ]
          employees.find_each do |employee|
            salary = employee.current_salary
            builder << [
              employee.name, employee.email, employee.job_title, employee.department,
              employee.country, employee.currency, employee.status, employee.hire_date,
              salary&.amount, salary&.frequency, salary&.effective_date
            ]
          end
        end

        send_data csv, type: "text/csv", filename: "acme_payroll_#{Date.current.iso8601}.csv"
      end

      private

      def set_employee
        @employee = Employee.find(params[:id])
      rescue ActiveRecord::RecordNotFound
        render json: { errors: [ "Employee not found" ] }, status: :not_found
      end

      def filtered_scope
        scope = Employee.includes(:salary_records)
        scope = scope.search(params[:q]) if params[:q].present?
        scope = scope.where(department: params[:department]) if params[:department].present?
        scope = scope.where(country: params[:country]) if params[:country].present?
        scope = scope.where(status: params[:status]) if params[:status].present?
        scope.order(:name)
      end

      def page
        [ params[:page].to_i, 1 ].max
      end

      def per_page
        params.fetch(:per_page, 20).to_i.clamp(1, 100)
      end

      def offset
        (page - 1) * per_page
      end

      def employee_params
        params.require(:employee).permit(
          :name, :email, :job_title, :department, :country, :currency, :hire_date, :status
        )
      end

      def render_errors(record)
        render json: { errors: record.errors.messages.transform_values(&:first) }, status: :unprocessable_entity
      end
    end
  end
end
