FactoryBot.define do
  factory :employee do
    name { Faker::Name.name }
    sequence(:email) { |n| "employee#{n}@acme.com" }
    job_title { Faker::Job.title }
    department { Faker::Commerce.department(max: 1) }
    country { Faker::Address.country_code }
    currency { "USD" }
    hire_date { Faker::Date.between(from: 15.years.ago, to: Date.today) }
    status { "active" }
  end
end
