require "rails_helper"

# Proves the full stack wiring: Rails serves the built SPA, React signs in,
# fetches from the API, and real payroll data renders in the browser.
RSpec.describe "Employee list (system)", type: :system do
  before do
    skip "build the frontend first (cd frontend && npm run build)" unless File.exist?(Rails.public_path.join("index.html"))
    create(:user, email: "hr@acme.example", password: "password123")
    create(:employee, name: "Priya Sharma", email: "priya@acme.example", department: "Engineering")
  end

  it "signs in and renders employees from the API" do
    visit "/login"
    fill_in "Email", with: "hr@acme.example"
    fill_in "Password", with: "password123"
    click_button "Sign in"

    visit "/employees"

    expect(page).to have_content("Employees")
    expect(page).to have_link("Priya Sharma")
    expect(page).to have_content("priya@acme.example")
  end
end
