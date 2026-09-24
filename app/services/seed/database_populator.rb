module Seed
  # Creates a deterministic, realistic dataset of employees and salary history.
  # Uses bulk inserts (insert_all) so 10,000 employees seed in seconds.
  class DatabasePopulator
    DEPARTMENT_MULTIPLIERS = {
      "Engineering" => 1.30,
      "Product" => 1.20,
      "Sales" => 1.15,
      "Finance" => 1.10,
      "Legal" => 1.10,
      "Operations" => 1.00,
      "Marketing" => 1.00,
      "Design" => 1.05,
      "Customer Support" => 0.75,
      "HR" => 0.95
    }.freeze

    # Supported currencies: INR (India, paid monthly) and USD (US, paid annually).
    # Country => local currency + salary convention. amount is expressed as an
    # ANNUALIZED figure in local currency; the stored value is derived from the
    # frequency (monthly countries store amount / 12).
    COUNTRY_CONFIG = {
      "IN" => { currency: "INR", frequency: "monthly", min: 300_000, max: 3_500_000 },
      "US" => { currency: "USD", frequency: "annual", min: 50_000, max: 200_000 }
    }.freeze

    BATCH_SIZE = 1_000

    attr_reader :rng, :country_config

    def initialize(seed: 12_345, employee_count: 10_000)
      @rng = Random.new(seed)
      @employee_count = employee_count
      Faker::Config.random = rng
      @country_config = COUNTRY_CONFIG
    end

    def call
      raise "employees table is not empty. Seed runs once on a fresh database; use bin/rails db:reset to reseed." if Employee.exists?

      employees = Array.new(@employee_count) { |index| employee_attributes(index) }
      employee_ids, employee_time = measure { insert_rows(Employee, employees) }
      salary_rows = salary_rows_for(employee_ids, employees)
      salary_ids, salary_time = measure { insert_rows(SalaryRecord, salary_rows) }
      component_rows = component_rows_for(salary_ids, salary_rows)
      _, component_time = measure { insert_rows(SalaryComponent, component_rows, return_ids: false) }

      {
        employee_count: employee_ids.size,
        salary_record_count: salary_ids.size,
        salary_component_count: component_rows.size,
        timings: { employees: employee_time, salary_records: salary_time, salary_components: component_time }
      }
    end

    private

    def insert_rows(model, rows, return_ids: true)
      ids = []
      rows.each_slice(BATCH_SIZE) do |batch|
        if return_ids
          result = model.insert_all(batch, returning: %w[id])
          ids.concat(result.map { |row| row["id"] })
        else
          model.insert_all(batch)
        end
      end
      ids
    end

    def measure
      started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      result = yield
      [ result, Process.clock_gettime(Process::CLOCK_MONOTONIC) - started ]
    end

    def employee_attributes(index)
      country_code = country_config.keys.sample(random: rng)
      config = country_config.fetch(country_code)
      name = Faker::Name.name
      {
        name: name,
        email: "#{name.parameterize}.#{index + 1}@acme.example",
        job_title: Faker::Job.title,
        department: DEPARTMENT_MULTIPLIERS.keys.sample(random: rng),
        country: country_code,
        currency: config.fetch(:currency),
        hire_date: hire_date,
        status: status,
        created_at: Time.current,
        updated_at: Time.current
      }
    end

    # Returns salary rows grouped per employee. 55% get 3 records
    # (hire + 2 raises), 30% get 2, 15% get 1.
    def salary_rows_for(employee_ids, employees)
      employee_ids.zip(employees).flat_map do |employee_id, attrs|
        count = [ 1, 2, 3, 3, 3 ].sample(random: rng)
        (0...count).map { |raise_idx| salary_row(attrs, employee_id, raise_idx, count) }
      end
    end

    def salary_row(attrs, employee_id, raise_index, total_raises)
      config = country_config.fetch(attrs[:country])
      current_annual = annualized_amount(attrs, config)
      # The latest record is the current salary; earlier records are fractions
      # of it so history grows monotonically (0.65, 0.85, 1.0 for 3 raises).
      fraction = raise_index == total_raises - 1 ? 1.0 : 0.65 + (raise_index * 0.2)
      annual = current_annual * fraction

      amount = config[:frequency] == "monthly" ? (annual / 12).round(2) : annual.round(2)

      {
        employee_id: employee_id,
        amount: amount,
        currency: config.fetch(:currency),
        frequency: config.fetch(:frequency),
        effective_date: effective_date_for_raise(attrs[:hire_date], total_raises, raise_index),
        created_at: Time.current,
        updated_at: Time.current
      }
    end

    # A realistic CTC breakdown per salary record: earnings sum to the gross
    # (the record's amount), and deductions reduce it to net pay.
    def component_rows_for(salary_ids, salary_rows)
      salary_ids.zip(salary_rows).flat_map do |salary_id, row|
        gross = row[:amount].to_d
        basic = (gross * 0.45).round(2)
        hra = (gross * 0.18).round(2)
        special = (gross - basic - hra).round(2)
        provident_fund = (basic * 0.12).round(2)
        income_tax = (gross * 0.10).round(2)
        now = Time.current

        [
          { salary_record_id: salary_id, name: "Basic", kind: "earning", amount: basic, position: 1, created_at: now, updated_at: now },
          { salary_record_id: salary_id, name: "House Rent Allowance", kind: "earning", amount: hra, position: 2, created_at: now, updated_at: now },
          { salary_record_id: salary_id, name: "Special Allowance", kind: "earning", amount: special, position: 3, created_at: now, updated_at: now },
          { salary_record_id: salary_id, name: "Provident Fund", kind: "deduction", amount: provident_fund, position: 4, created_at: now, updated_at: now },
          { salary_record_id: salary_id, name: "Income Tax", kind: "deduction", amount: income_tax, position: 5, created_at: now, updated_at: now }
        ]
      end
    end

    def annualized_amount(attrs, config)
      base = config.fetch(:min) + (rng.rand * (config.fetch(:max) - config.fetch(:min)))
      multiplier = DEPARTMENT_MULTIPLIERS.fetch(attrs[:department])
      tenure = [ ((Date.today - attrs[:hire_date]).to_i / 365), 12 ].min
      (base * multiplier * (1.0 + (tenure * 0.015))).round(2)
    end

    def effective_date_for_raise(hire_date, total_raises, raise_index)
      return hire_date if total_raises == 1 || raise_index.zero?

      days_between = ((Date.today - hire_date).to_i / total_raises)
      hire_date + (days_between * raise_index)
    end

    def hire_date
      Faker::Date.between(from: Date.new(2005, 1, 1), to: Date.today)
    end

    def status
      rng.rand < 0.95 ? "active" : "terminated"
    end
  end
end
