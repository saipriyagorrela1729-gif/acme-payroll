require "rails_helper"

RSpec.describe "Api::V1::Summary", type: :request do
  let(:headers) { auth_headers }

  it "returns payroll summary stats" do
    employee = create(:employee, country: "US", currency: "USD")
    create(:salary_record, employee: employee, amount: 100_000, frequency: "annual")

    get "/api/v1/summary", headers: headers

    expect(response).to have_http_status(:ok)
    expect(json["summary"]["headcount"]["total"]).to eq(1)
    expect(json["summary"]["payroll"]["USD"]["annualized"]).to eq(100_000.0)
    expect(json["summary"]["top_earners"]["USD"].first["name"]).to eq(employee.name)
  end

  it "is consistent with the stored records" do
    create_list(:employee, 5, currency: "USD", country: "US")
      .each { |e| create(:salary_record, employee: e, amount: 50_000, frequency: "annual") }

    get "/api/v1/summary", headers: headers

    expect(json["summary"]["payroll"]["USD"]["annualized"]).to eq(250_000.0)
    expect(json["summary"]["by_department"].sum { |r| r["employees"] }).to eq(5)
  end
end
