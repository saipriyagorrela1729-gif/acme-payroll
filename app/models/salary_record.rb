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
  has_many :salary_components, -> { order(:position, :id) }, dependent: :destroy, inverse_of: :salary_record
  accepts_nested_attributes_for :salary_components, allow_destroy: true, reject_if: :all_blank

  validates :amount, presence: true, numericality: { greater_than: 0 }
  validates :currency, presence: true, format: { with: /\A[A-Z]{3}\z/, message: "must be a 3-letter ISO 4217 code" }
  validates :frequency, inclusion: { in: VALID_FREQUENCIES }
  validates :effective_date, presence: true

  # When a breakdown is provided, the record's `amount` is the GROSS (sum of the
  # earning components) so all existing analytics keep working unchanged.
  before_validation :sync_amount_from_earnings

  scope :for_year, ->(year) { where("effective_date <= ?", Date.new(year, 12, 31)) }

  # Normalizes any salary to an annual figure for cross-frequency comparison.
  def annualized_amount
    case frequency
    when "annual" then amount.to_d
    when "monthly" then amount.to_d * MONTHS_PER_YEAR
    when "hourly" then amount.to_d * HOURS_PER_YEAR
    end
  end

  # Gross = sum of earning components (falls back to `amount` when no breakdown).
  def gross_earnings
    earnings = salary_components.select(&:earning?)
    earnings.any? ? earnings.sum { |component| component.amount.to_d } : amount.to_d
  end

  def total_deductions
    salary_components.select(&:deduction?).sum { |component| component.amount.to_d }
  end

  def net_pay
    gross_earnings - total_deductions
  end

  private

  def sync_amount_from_earnings
    earnings = salary_components.reject(&:marked_for_destruction?).select(&:earning?)
    self.amount = earnings.sum { |component| component.amount.to_d } if earnings.any?
  end
end
