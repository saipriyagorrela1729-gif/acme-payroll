FactoryBot.define do
  factory :salary_record do
    employee
    amount { Faker::Number.between(from: 20_000, to: 250_000) }
    currency { employee.currency }
    frequency { "annual" }
    effective_date { Faker::Date.between(from: 10.years.ago, to: Date.today) }
  end
end
