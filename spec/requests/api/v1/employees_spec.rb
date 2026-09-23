require "rails_helper"

RSpec.describe "Api::V1::Employees", type: :request do
  let(:headers) { { "Content-Type" => "application/json" } }

  describe "GET /api/v1/employees" do
    it "returns a paginated list of employees with meta" do
      create_list(:employee, 3)

      get "/api/v1/employees"

      expect(response).to have_http_status(:ok)
      expect(json["data"].size).to eq(3)
      expect(json["meta"]).to include("page" => 1, "per_page" => 20, "total_count" => 3, "total_pages" => 1)
    end

    it "paginates results" do
      create_list(:employee, 5)

      get "/api/v1/employees", params: { page: 2, per_page: 2 }

      expect(json["data"].size).to eq(2)
      expect(json["meta"]["page"]).to eq(2)
      expect(json["meta"]["total_pages"]).to eq(3)
    end

    it "caps per_page at 100" do
      get "/api/v1/employees", params: { per_page: 500 }
      expect(json["meta"]["per_page"]).to eq(100)
    end

    it "includes the current salary on each employee" do
      employee = create(:employee)
      create(:salary_record, employee: employee, amount: 90_000, frequency: "annual")

      get "/api/v1/employees"

      payload = json["data"].first
      expect(payload["current_salary"]["amount"]).to eq("90000.0")
      expect(payload["current_salary"]["annualized_amount"]).to eq("90000.0")
    end

    it "returns null current_salary when the employee has none" do
      create(:employee)

      get "/api/v1/employees"

      expect(json["data"].first["current_salary"]).to be_nil
    end

    it "searches by name or email" do
      create(:employee, name: "Priya Sharma", email: "priya@acme.example")
      create(:employee, name: "John Doe", email: "john@acme.example")

      get "/api/v1/employees", params: { q: "priya" }
      expect(json["data"].size).to eq(1)
      expect(json["data"].first["email"]).to eq("priya@acme.example")

      get "/api/v1/employees", params: { q: "@acme.example" }
      expect(json["data"].size).to eq(2)
    end

    it "filters by department, country, and status" do
      create(:employee, department: "Engineering", country: "IN")
      create(:employee, department: "Sales", country: "US", status: "terminated")
      create(:employee, department: "Engineering", country: "US", status: "active")

      get "/api/v1/employees", params: { department: "Engineering" }
      expect(json["data"].size).to eq(2)

      get "/api/v1/employees", params: { department: "Engineering", country: "US" }
      expect(json["data"].size).to eq(1)

      get "/api/v1/employees", params: { status: "terminated" }
      expect(json["data"].size).to eq(1)
    end

    it "does not run an N+1 query per employee (salary history preloaded)" do
      create_list(:employee, 10).each { |e| create(:salary_record, employee: e) }

      queries = []
      ActiveSupport::Notifications.subscribed(
        lambda { |*args| queries << args[4][:sql] if args[4][:sql].match?(/\ASELECT/) },
        "sql.active_record"
      ) do
        get "/api/v1/employees", params: { per_page: 10 }
      end

      salary_queries = queries.count { |sql| sql.include?("salary_records") }
      expect(salary_queries).to be <= 2
    end
  end

  describe "GET /api/v1/employees/:id" do
    it "returns the employee with salary history" do
      employee = create(:employee)
      create(:salary_record, employee: employee, amount: 70_000, effective_date: Date.new(2023, 1, 1))
      create(:salary_record, employee: employee, amount: 80_000, effective_date: Date.new(2024, 1, 1))

      get "/api/v1/employees/#{employee.id}"

      expect(response).to have_http_status(:ok)
      expect(json["employee"]["id"]).to eq(employee.id)
      expect(json["employee"]["salary_history"].size).to eq(2)
      expect(json["employee"]["salary_history"].first["amount"]).to eq("80000.0")
    end

    it "returns 404 for a missing employee" do
      get "/api/v1/employees/999999"

      expect(response).to have_http_status(:not_found)
      expect(json["errors"]).to include("Employee not found")
    end
  end

  describe "POST /api/v1/employees" do
    let(:valid_params) do
      {
        employee: {
          name: "Priya Sharma",
          email: "priya.sharma@acme.example",
          job_title: "Backend Engineer",
          department: "Engineering",
          country: "IN",
          currency: "INR",
          hire_date: "2022-06-01"
        }
      }
    end

    it "creates an employee" do
      post "/api/v1/employees", params: valid_params.to_json, headers: headers

      expect(response).to have_http_status(:created)
      expect(json["employee"]["name"]).to eq("Priya Sharma")
      expect(Employee.count).to eq(1)
    end

    it "returns 422 with validation errors for invalid params" do
      post "/api/v1/employees", params: { employee: { name: "", email: "bad" } }.to_json, headers: headers

      expect(response).to have_http_status(:unprocessable_content)
      expect(json["errors"]).to have_key("email")
      expect(json["errors"]).to have_key("job_title")
    end
  end

  describe "PATCH /api/v1/employees/:id" do
    it "updates employee attributes" do
      employee = create(:employee, name: "Old Name")

      patch "/api/v1/employees/#{employee.id}", params: { employee: { name: "New Name", status: "terminated" } }.to_json, headers: headers

      expect(response).to have_http_status(:ok)
      expect(json["employee"]["name"]).to eq("New Name")
      expect(employee.reload.status).to eq("terminated")
    end

    it "returns 404 for a missing employee" do
      patch "/api/v1/employees/999999", params: { employee: { name: "X" } }.to_json, headers: headers
      expect(response).to have_http_status(:not_found)
    end
  end

  describe "DELETE /api/v1/employees/:id" do
    it "deletes the employee and their salary history" do
      employee = create(:employee)
      create(:salary_record, employee: employee)

      delete "/api/v1/employees/#{employee.id}"

      expect(response).to have_http_status(:no_content)
      expect(Employee.exists?(employee.id)).to be(false)
      expect(SalaryRecord.where(employee_id: employee.id).count).to eq(0)
    end
  end

  describe "POST /api/v1/employees/:id/salary_records" do
    let(:employee) { create(:employee) }
    let(:valid_params) do
      {
        salary_record: {
          amount: 1_200_000,
          currency: "INR",
          frequency: "monthly",
          effective_date: "2025-01-01"
        }
      }
    end

    it "adds a salary record" do
      post "/api/v1/employees/#{employee.id}/salary_records", params: valid_params.to_json, headers: headers

      expect(response).to have_http_status(:created)
      expect(json["salary_record"]["amount"]).to eq("1200000.0")
      expect(employee.salary_records.count).to eq(1)
    end

    it "rejects a non-positive amount" do
      post "/api/v1/employees/#{employee.id}/salary_records",
           params: { salary_record: { amount: -5, currency: "INR", frequency: "monthly", effective_date: "2025-01-01" } }.to_json,
           headers: headers

      expect(response).to have_http_status(:unprocessable_content)
      expect(json["errors"]).to have_key("amount")
    end

    it "rejects a salary_record for a missing employee" do
      post "/api/v1/employees/999999/salary_records", params: valid_params.to_json, headers: headers
      expect(response).to have_http_status(:not_found)
    end
  end

  describe "GET /api/v1/departments and /countries" do
    before { create_list(:employee, 5) }

    it "returns distinct departments" do
      get "/api/v1/departments"
      expect(json["departments"]).to eq(Employee.distinct.pluck(:department).sort)
    end

    it "returns distinct countries" do
      get "/api/v1/countries"
      expect(json["countries"]).to eq(Employee.distinct.pluck(:country).sort)
    end
  end
end
