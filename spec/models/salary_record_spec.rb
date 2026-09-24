require "rails_helper"

RSpec.describe SalaryRecord, type: :model do
  describe "associations" do
    it { is_expected.to belong_to(:employee) }
    it { is_expected.to have_many(:salary_components).dependent(:destroy) }
  end

  describe "validations" do
    it { is_expected.to validate_presence_of(:amount) }
    it { is_expected.to validate_numericality_of(:amount).is_greater_than(0) }
    it { is_expected.to validate_presence_of(:currency) }
    it { is_expected.to validate_presence_of(:effective_date) }
    it { is_expected.to validate_inclusion_of(:frequency).in_array(%w[annual monthly hourly]) }

    it "rejects a malformed ISO currency code" do
      record = build(:salary_record, currency: "inr1")
      expect(record).not_to be_valid
    end

    it "rejects a non-positive amount" do
      record = build(:salary_record, amount: 0)
      expect(record).not_to be_valid
    end
  end

  describe "#annualized_amount" do
    it "returns the amount unchanged for annual salaries" do
      record = build(:salary_record, frequency: "annual", amount: 75_000)
      expect(record.annualized_amount).to eq(75_000)
    end

    it "multiplies monthly salaries by 12" do
      record = build(:salary_record, frequency: "monthly", amount: 5_000)
      expect(record.annualized_amount).to eq(60_000)
    end

    it "multiplies hourly salaries by 2080 hours" do
      record = build(:salary_record, frequency: "hourly", amount: 25)
      expect(record.annualized_amount).to eq(52_000)
    end
  end

  describe "salary breakdown" do
    it "computes gross earnings, deductions and net pay" do
      record = create(:salary_record, amount: 1_000, frequency: "monthly")
      create(:salary_component, salary_record: record, name: "Basic", kind: "earning", amount: 600)
      create(:salary_component, salary_record: record, name: "HRA", kind: "earning", amount: 400)
      create(:salary_component, salary_record: record, name: "Provident Fund", kind: "deduction", amount: 100)

      record.reload

      expect(record.gross_earnings).to eq(1_000)
      expect(record.total_deductions).to eq(100)
      expect(record.net_pay).to eq(900)
    end

    it "falls back to the amount when there is no breakdown" do
      record = create(:salary_record, amount: 5_000)

      expect(record.gross_earnings).to eq(5_000)
      expect(record.total_deductions).to eq(0)
      expect(record.net_pay).to eq(5_000)
    end

    it "syncs the record's amount to the sum of earnings" do
      record = build(:salary_record, amount: 1, employee: create(:employee))
      record.salary_components.build(name: "Basic", kind: "earning", amount: 700)
      record.salary_components.build(name: "HRA", kind: "earning", amount: 300)

      record.save!

      expect(record.amount).to eq(1_000)
    end
  end
end
