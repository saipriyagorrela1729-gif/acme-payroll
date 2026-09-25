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

    # Country-appropriate CTC breakdown templates. Earnings must sum to the gross
    # (the last earning uses :remainder). Deductions reduce it to net pay.
    COMPONENT_CONFIG = {
      "INR" => [
        { name: "Basic", kind: "earning", percent: 0.45 },
        { name: "House Rent Allowance", kind: "earning", percent: 0.18 },
        { name: "Special Allowance", kind: "earning", remainder: true },
        { name: "Provident Fund", kind: "deduction", percent_of_basic: 0.12 },
        { name: "Professional Tax", kind: "deduction", flat: 200 },
        { name: "Income Tax", kind: "deduction", percent: 0.10 }
      ],
      "USD" => [
        { name: "Base", kind: "earning", percent: 0.85 },
        { name: "Bonus", kind: "earning", remainder: true },
        { name: "401(k)", kind: "deduction", percent: 0.05 },
        { name: "Federal Income Tax", kind: "deduction", percent: 0.12 },
        { name: "State Tax", kind: "deduction", percent: 0.05 }
      ]
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

    # A country-appropriate CTC breakdown per salary record: earning components
    # sum to the gross (the record's amount), deductions reduce it to net pay.
    # Only the CURRENT (latest) record per employee gets a breakdown — that is
    # what the UI shows; history is displayed as amounts. This keeps the seed
    # fast enough to run before the server binds.
    def component_rows_for(salary_ids, salary_rows)
      now = Time.current
      current_pairs = salary_ids.zip(salary_rows)
                               .group_by { |_id, row| row[:employee_id] }
                               .values
                               .map(&:last)

      current_pairs.flat_map do |salary_id, row|
        templates = COMPONENT_CONFIG.fetch(row[:currency])
        amounts = component_amounts(row[:amount].to_d, templates)

        templates.each_with_index.map do |template, index|
          {
            salary_record_id: salary_id,
            name: template[:name],
            kind: template[:kind],
            amount: amounts[index],
            position: index + 1,
            created_at: now,
            updated_at: now
          }
        end
      end
    end

    # Resolves each template to an amount. The `remainder` earning absorbs
    # rounding so the earning components always sum exactly to the gross.
    def component_amounts(gross, templates)
      resolved = {}
      basic = 0.to_d

      templates.each_with_index do |template, index|
        next if template[:remainder]

        amount =
          if template[:percent_of_basic]
            (basic * template[:percent_of_basic]).round(2)
          elsif template[:percent]
            (gross * template[:percent]).round(2)
          elsif template[:flat]
            template[:flat].to_d
          else
            0.to_d
          end

        basic = amount if template[:name] == "Basic"
        resolved[index] = amount
      end

      remainder_index = templates.index { |template| template[:remainder] }
      if remainder_index
        earning_sum = templates.each_with_index
                              .select { |template, index| template[:kind] == "earning" && index != remainder_index }
                              .sum { |_template, index| resolved[index] }
        resolved[remainder_index] = (gross - earning_sum).round(2)
      end

      templates.each_index.map { |index| resolved[index] }
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
