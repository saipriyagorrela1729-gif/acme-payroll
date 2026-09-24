class SalaryComponent < ApplicationRecord
  KINDS = %w[earning deduction].freeze

  belongs_to :salary_record

  validates :name, presence: true
  validates :kind, inclusion: { in: KINDS }
  validates :amount, presence: true, numericality: { greater_than_or_equal_to: 0 }

  scope :earnings, -> { where(kind: "earning") }
  scope :deductions, -> { where(kind: "deduction") }

  def earning?
    kind == "earning"
  end

  def deduction?
    kind == "deduction"
  end
end
