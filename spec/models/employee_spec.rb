require "rails_helper"

RSpec.describe Employee, type: :model do
  describe "validations" do
    it { is_expected.to validate_presence_of(:name) }
    it { is_expected.to validate_presence_of(:email) }
    it { is_expected.to validate_presence_of(:job_title) }
    it { is_expected.to validate_presence_of(:department) }
    it { is_expected.to validate_presence_of(:country) }
    it { is_expected.to validate_presence_of(:currency) }
    it { is_expected.to validate_presence_of(:hire_date) }

    it { is_expected.to validate_inclusion_of(:status).in_array(%w[active terminated]) }

    describe "email" do
      it "rejects an invalid format" do
        employee = build(:employee, email: "not-an-email")
        expect(employee).not_to be_valid
      end

      it "requires uniqueness" do
        create(:employee, email: "duplicate@acme.com")
        employee = build(:employee, email: "duplicate@acme.com")
        expect(employee).not_to be_valid
        expect(employee.errors[:email]).to include("has already been taken")
      end
    end

    describe "currency" do
      it "rejects a malformed ISO code" do
        employee = build(:employee, currency: "USD1")
        expect(employee).not_to be_valid
      end
    end
  end

  describe "associations" do
    it { is_expected.to have_many(:salary_records).dependent(:destroy) }
  end

  describe "#current_salary" do
    it "returns the latest salary by effective_date" do
      employee = create(:employee)
      old = create(:salary_record, employee: employee, effective_date: Date.new(2023, 1, 1), amount: 50_000)
      latest = create(:salary_record, employee: employee, effective_date: Date.new(2024, 6, 1), amount: 60_000)

      expect(employee.current_salary).to eq(latest)
      expect(employee.current_salary).not_to eq(old)
    end

    it "returns nil when the employee has no salary records" do
      employee = create(:employee)
      expect(employee.current_salary).to be_nil
    end

    it "ties by id when effective_dates are equal" do
      employee = create(:employee)
      create(:salary_record, employee: employee, effective_date: Date.new(2024, 1, 1))
      newest_id = create(:salary_record, employee: employee, effective_date: Date.new(2024, 1, 1)).id

      expect(employee.current_salary.id).to eq(newest_id)
    end
  end
end
