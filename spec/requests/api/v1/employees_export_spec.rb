require "rails_helper"

RSpec.describe "Api::V1::Employees CSV export", type: :request do
  let(:headers) { auth_headers }

  it "returns a CSV of all employees with their current salary" do
    employee = create(:employee, name: "Priya Sharma", email: "priya@acme.example", country: "US", currency: "USD")
    create(:salary_record, employee: employee, amount: 90_000, frequency: "annual", effective_date: Date.new(2024, 6, 1))

    get "/api/v1/employees/export.csv", headers: headers

    expect(response).to have_http_status(:ok)
    expect(response.content_type).to include("text/csv")

    csv = CSV.parse(response.body, headers: true)
    expect(csv.headers).to include("name", "email", "department", "country", "salary_amount")

    row = csv.find { |r| r["email"] == "priya@acme.example" }
    expect(row["name"]).to eq("Priya Sharma")
    expect(row["salary_amount"]).to eq("90000.0")
    expect(row["salary_frequency"]).to eq("annual")
  end

  it "exports all employees regardless of pagination defaults" do
    create_list(:employee, 25)

    get "/api/v1/employees/export.csv", headers: headers

    expect(CSV.parse(response.body, headers: true).size).to eq(25)
  end

  it "shows no salary columns for an employee without a salary record" do
    employee = create(:employee)

    get "/api/v1/employees/export.csv", headers: headers

    row = CSV.parse(response.body, headers: true).find { |r| r["email"] == employee.email }
    expect(row["salary_amount"]).to be_blank
  end
end
