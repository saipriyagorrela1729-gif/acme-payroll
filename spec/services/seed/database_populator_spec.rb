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

    it "creates a CTC breakdown for every salary record whose earnings sum to the gross" do
      result = Seed::DatabasePopulator.new(employee_count: 20).call

      expect(result[:salary_component_count]).to eq(result[:salary_record_count] * 5)

      record = SalaryRecord.first
      expect(record.salary_components.map(&:name)).to include("Basic", "House Rent Allowance", "Provident Fund")
      expect(record.gross_earnings).to eq(record.amount)
      expect(record.net_pay).to be < record.gross_earnings
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
