module Api
  module V1
    class SalaryRecordSerializer
      def self.call(record)
        return nil unless record

        {
          id: record.id,
          amount: record.amount.to_s,
          currency: record.currency,
          frequency: record.frequency,
          effective_date: record.effective_date,
          annualized_amount: record.annualized_amount.to_s
        }
      end
    end
  end
end
