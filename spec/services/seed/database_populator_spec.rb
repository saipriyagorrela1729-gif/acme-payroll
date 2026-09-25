require "rails_helper"

RSpec.describe Seed::DatabasePopulator, type: :service do
  describe "#call" do
    it "creates the requested number of employees" do
      result = Seed::DatabasePopulator.new(employee_count: 50).call

      expect(result[:employee_count]).to eq(50)
      expect(Employee.count).to eq(50)
    end

    it "creates salary history for every employee" do
      Seed::DatabasePopulator.new(employee_count: 50).call

      expect(SalaryRecord.count).to be >= 50
      expect(Employee.all.all? { |e| e.salary_records.any? }).to be(true)
    end

    it "creates a current salary matching the latest effective_date" do
      Seed::DatabasePopulator.new(employee_count: 50).call

      Employee.find_each do |employee|
        latest = employee.salary_records.order(effective_date: :desc, id: :desc).first
        expect(employee.current_salary.id).to eq(latest.id)
      end
    end

    it "creates a country-appropriate CTC breakdown whose earnings sum to the gross" do
      Seed::DatabasePopulator.new(employee_count: 100).call

      expect(SalaryComponent.count).to be > SalaryRecord.count

      inr_record = SalaryRecord.where(currency: "INR").first
      usd_record = SalaryRecord.where(currency: "USD").first

      expect(inr_record.salary_components.map(&:name)).to include("Basic", "House Rent Allowance", "Provident Fund")
      expect(usd_record.salary_components.map(&:name)).to include("Base", "401(k)", "Federal Income Tax")

      # India-only components must never leak onto US records
      expect(usd_record.salary_components.map(&:name)).not_to include("House Rent Allowance", "Provident Fund")

      [ inr_record, usd_record ].each do |record|
        expect(record.gross_earnings).to eq(record.amount)
        expect(record.net_pay).to be < record.gross_earnings
      end
    end

    it "is deterministic for a fixed seed" do
      Seed::DatabasePopulator.new(seed: 999, employee_count: 30).call
      first_run = SalaryRecord.sum(:amount)

      SalaryComponent.delete_all
      SalaryRecord.delete_all
      Employee.delete_all

      Seed::DatabasePopulator.new(seed: 999, employee_count: 30).call
      second_run = SalaryRecord.sum(:amount)

      expect(second_run).to eq(first_run)
    end

    it "uses only INR and USD across the two supported countries" do
      Seed::DatabasePopulator.new(employee_count: 100).call

      expect(SalaryRecord.distinct.pluck(:currency)).to match_array(%w[INR USD])
      expect(Employee.distinct.pluck(:country)).to match_array(%w[IN US])
      expect(SalaryRecord.distinct.pluck(:frequency)).to include("annual", "monthly")
    end

    it "refuses to seed a database that already has employees" do
      create(:employee)
      expect { Seed::DatabasePopulator.new(employee_count: 10).call }
        .to raise_error(/not empty/)
    end
  end
end
