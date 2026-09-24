module Api
  module V1
    class SalaryRecordSerializer
      def self.call(record, include_components: false)
        return nil unless record

        payload = {
          id: record.id,
          amount: record.amount.to_s,
          currency: record.currency,
          frequency: record.frequency,
          effective_date: record.effective_date,
          annualized_amount: record.annualized_amount.to_s,
          gross_earnings: record.gross_earnings.to_s,
          total_deductions: record.total_deductions.to_s,
          net_pay: record.net_pay.to_s
        }

        if include_components
          payload[:salary_components] = record.salary_components.map { |c| SalaryComponentSerializer.call(c) }
        end

        payload
      end
    end
  end
end
