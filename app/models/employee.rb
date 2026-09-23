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
    query = "%#{term.to_s.strip.downcase}%"
    where("LOWER(name) LIKE :q OR LOWER(email) LIKE :q", q: query)
  end

  # Works on the in-memory collection when salary_records are preloaded
  # (via includes) so list endpoints avoid N+1 queries.
  def current_salary
    salary_records.max_by { |record| [ record.effective_date, record.id ] }
  end
end
