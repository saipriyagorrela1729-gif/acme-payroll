class Employee < ApplicationRecord
  VALID_STATUSES = %w[active terminated].freeze

  has_many :salary_records, dependent: :destroy

  validates :name, :email, :job_title, :department, :country, :currency, :hire_date, presence: true
  validates :email, format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :email, uniqueness: true
  validates :currency, format: { with: /\A[A-Z]{3}\z/, message: "must be a 3-letter ISO 4217 code" }
  validates :status, inclusion: { in: VALID_STATUSES }

  scope :active, -> { where(status: "active") }
  scope :search, ->(term) do
    where("name ILIKE :q OR email ILIKE :q", q: "%#{term.to_s.strip}%")
  end

  def current_salary
    salary_records.order(effective_date: :desc, id: :desc).first
  end
end
