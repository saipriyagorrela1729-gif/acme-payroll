require "rails_helper"

# Proves the full stack wiring: Rails serves the built SPA, React fetches from
# the API, and real payroll data renders in the browser. Kept to one happy path
# so the suite stays fast and deterministic.
RSpec.describe "Employee list (system)", type: :system do
  before do
    skip "build the frontend first (cd frontend && npm run build)" unless File.exist?(Rails.public_path.join("index.html"))
    create(:employee, name: "Priya Sharma", email: "priya@acme.example", department: "Engineering")
  end

  it "renders employees from the API" do
    visit "/employees"

    expect(page).to have_content("Employees")
    expect(page).to have_link("Priya Sharma")
    expect(page).to have_content("priya@acme.example")
  end
end
