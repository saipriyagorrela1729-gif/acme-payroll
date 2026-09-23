module Api
  module V1
    class EmployeeSerializer
      def self.call(employee, include_history: false)
        payload = {
          id: employee.id,
          name: employee.name,
          email: employee.email,
          job_title: employee.job_title,
          department: employee.department,
          country: employee.country,
          currency: employee.currency,
          hire_date: employee.hire_date,
          status: employee.status,
          current_salary: SalaryRecordSerializer.call(employee.current_salary)
        }

        if include_history
          history = employee.salary_records.sort_by { |r| [ r.effective_date, r.id ] }.reverse
          payload[:salary_history] = history.map { |r| SalaryRecordSerializer.call(r) }
        end

        payload
      end
    end
  end
end
