require "rails_helper"

RSpec.describe PayrollStats, type: :service do
  let(:us_engineer_monthly) do
    create(:employee, name: "Alice", department: "Engineering", country: "US", currency: "USD")
  end
  let(:us_engineer_annual) do
    create(:employee, name: "Bob", department: "Engineering", country: "US", currency: "USD")
  end
  let(:in_sales) do
    create(:employee, name: "Carla", department: "Sales", country: "IN", currency: "INR")
  end

  before do
    # Alice: monthly 5,000 -> annualized 60,000 (with a lower older record)
    create(:salary_record, employee: us_engineer_monthly, amount: 4_000, frequency: "monthly", effective_date: Date.new(2023, 1, 1))
    create(:salary_record, employee: us_engineer_monthly, amount: 5_000, frequency: "monthly", effective_date: Date.new(2024, 1, 1))
    # Bob: annual 100,000
    create(:salary_record, employee: us_engineer_annual, amount: 100_000, frequency: "annual", effective_date: Date.new(2024, 1, 1))
    # Carla: annual 1,200,000 INR
    create(:salary_record, employee: in_sales, amount: 1_200_000, frequency: "annual", effective_date: Date.new(2024, 1, 1))
  end

  subject(:stats) { described_class.new.call }

  describe "headcount" do
    it "counts total, active, and terminated employees" do
      us_engineer_annual.update(status: "terminated")

      expect(stats[:headcount]).to eq(total: 3, active: 2, terminated: 1)
    end
  end

  describe "payroll" do
    it "sums annualized salaries per currency and derives the monthly figure" do
      expect(stats[:payroll]["USD"]).to eq("annualized" => 160_000.0, "monthly" => 13_333.33)
      expect(stats[:payroll]["INR"]).to eq("annualized" => 1_200_000.0, "monthly" => 100_000.0)
    end

    it "uses only the CURRENT salary, not history" do
      # Alice's older 4,000/month record must not be double-counted
      expect(stats[:payroll]["USD"]["annualized"]).to eq(160_000.0)
    end
  end

  describe "by_department" do
    it "returns avg and median annualized salary per department and currency" do
      engineering = stats[:by_department].find { |r| r[:name] == "Engineering" }

      expect(engineering).to include(currency: "USD", employees: 2, average: 80_000.0, median: 80_000.0)
    end
  end

  describe "by_country" do
    it "returns avg and median per country and currency" do
      us = stats[:by_country].find { |r| r[:name] == "US" }
      ind = stats[:by_country].find { |r| r[:name] == "IN" }

      expect(us).to include(currency: "USD", employees: 2, average: 80_000.0, median: 80_000.0)
      expect(ind).to include(currency: "INR", employees: 1, average: 1_200_000.0, median: 1_200_000.0)
    end
  end

  describe "distribution" do
    it "returns a banded histogram per currency whose counts sum to headcount" do
      usd = stats[:distribution]["USD"]
      inr = stats[:distribution]["INR"]

      expect(usd.size).to eq(10)
      expect(usd.sum { |b| b[:count] }).to eq(2)
      expect(inr.sum { |b| b[:count] }).to eq(1)
      expect(usd.first[:label]).to be_present
    end
  end

  describe "top_earners" do
    it "returns the top earners per currency" do
      expect(stats[:top_earners]["USD"].first).to include(name: "Bob", department: "Engineering", annualized_amount: 100_000.0)
      expect(stats[:top_earners]["INR"].first).to include(name: "Carla", annualized_amount: 1_200_000.0)
    end

    it "caps the list per currency" do
      create_list(:employee, 12, currency: "USD", country: "US", department: "Engineering")
        .each { |e| create(:salary_record, employee: e, amount: 90_000, frequency: "annual") }

      expect(stats[:top_earners]["USD"].size).to eq(10)
    end
  end
end
