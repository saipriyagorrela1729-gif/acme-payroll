class SalaryRecord < ApplicationRecord
  VALID_FREQUENCIES = %w[annual monthly hourly].freeze
  HOURS_PER_YEAR = 2080
  MONTHS_PER_YEAR = 12

  # SQL fragment that normalizes any salary to an annual figure. Single source
  # of truth for aggregation (payroll, medians, distributions) so every report
  # uses the same convention. Convention: 40 h/week x 52 weeks = 2080 hours.
  ANNUALIZED_SQL = <<~SQL.squish
    CASE salary_records.frequency
      WHEN 'annual'  THEN salary_records.amount
      WHEN 'monthly' THEN salary_records.amount * #{MONTHS_PER_YEAR}
      WHEN 'hourly'  THEN salary_records.amount * #{HOURS_PER_YEAR}
    END
  SQL

  belongs_to :employee

  validates :amount, presence: true, numericality: { greater_than: 0 }
  validates :currency, presence: true, format: { with: /\A[A-Z]{3}\z/, message: "must be a 3-letter ISO 4217 code" }
  validates :frequency, inclusion: { in: VALID_FREQUENCIES }
  validates :effective_date, presence: true

  scope :for_year, ->(year) { where("effective_date <= ?", Date.new(year, 12, 31)) }

  # Normalizes any salary to an annual figure for cross-frequency comparison.
  def annualized_amount
    case frequency
    when "annual" then amount.to_d
    when "monthly" then amount.to_d * MONTHS_PER_YEAR
    when "hourly" then amount.to_d * HOURS_PER_YEAR
    end
  end
end
