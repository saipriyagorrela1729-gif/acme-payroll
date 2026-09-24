FactoryBot.define do
  factory :salary_component do
    salary_record
    name { "Basic" }
    kind { "earning" }
    amount { 1_000 }
    position { 0 }
  end
end
