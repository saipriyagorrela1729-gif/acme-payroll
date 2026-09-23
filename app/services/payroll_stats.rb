# Aggregates "how the org pays people" from the current salary of every employee.
# The current salaries are fetched in a single query (one row per employee, via a
# window function) and the statistics are computed in Ruby. This keeps the SQL
# portable across SQLite and PostgreSQL and avoids re-running the window function
# for every metric. All comparisons are grouped by currency (no FX).
class PayrollStats
  BUCKET_COUNT = 10

  def call
    salaries = current_salary_rows

    {
      headcount: headcount,
      payroll: payroll(salaries),
      by_department: grouped(salaries, :department),
      by_country: grouped(salaries, :country),
      distribution: distribution(salaries),
      top_earners: top_earners(salaries)
    }
  end

  private

  # One row per employee: the CURRENT (latest) salary, joined to the employee.
  # Uses a window function so it is portable across SQLite and PostgreSQL and
  # returns exactly one row per employee even when effective_dates tie.
  def current_salary_rows
    rows = SalaryRecord.connection.select_all(<<~SQL.squish).to_a
      SELECT currency, department, country, name, annualized
      FROM (
        SELECT salary_records.currency AS currency,
               employees.department AS department,
               employees.country AS country,
               employees.name AS name,
               #{SalaryRecord::ANNUALIZED_SQL} AS annualized,
               ROW_NUMBER() OVER (
                 PARTITION BY salary_records.employee_id
                 ORDER BY salary_records.effective_date DESC, salary_records.id DESC
               ) AS row_num
        FROM salary_records
        JOIN employees ON employees.id = salary_records.employee_id
      ) ranked_salaries
      WHERE row_num = 1
    SQL

    rows.map do |row|
      {
        currency: row["currency"],
        department: row["department"],
        country: row["country"],
        name: row["name"],
        annualized: row["annualized"].to_f
      }
    end
  end

  def headcount
    {
      total: Employee.count,
      active: Employee.active.count,
      terminated: Employee.where(status: "terminated").count
    }
  end

  def payroll(salaries)
    salaries.group_by { |salary| salary[:currency] }.transform_values do |group|
      annualized = group.sum { |salary| salary[:annualized] }
      { "annualized" => annualized.round(2), "monthly" => (annualized / 12).round(2) }
    end
  end

  def grouped(salaries, key)
    salaries.group_by { |salary| [ salary[key], salary[:currency] ] }.map do |(name, currency), group|
      amounts = group.map { |salary| salary[:annualized] }.sort
      {
        name: name,
        currency: currency,
        employees: amounts.size,
        average: (amounts.sum / amounts.size).round(2),
        median: median(amounts).round(2)
      }
    end
  end

  def median(sorted_amounts)
    size = sorted_amounts.size
    return sorted_amounts.first if size.odd?

    (sorted_amounts[(size / 2) - 1] + sorted_amounts[size / 2]) / 2.0
  end

  def distribution(salaries)
    salaries.group_by { |salary| salary[:currency] }
      .transform_values { |group| bucketize(group.map { |salary| salary[:annualized] }) }
  end

  def bucketize(amounts)
    min = amounts.min
    width = (amounts.max - min) / BUCKET_COUNT.to_f
    counts = Array.new(BUCKET_COUNT, 0)

    amounts.each do |amount|
      index = width.zero? ? 0 : [ ((amount - min) / width).floor, BUCKET_COUNT - 1 ].min
      counts[index] += 1
    end

    counts.each_with_index.map do |count, index|
      {
        band: index + 1,
        label: "#{(min + (index * width)).round(0)}–#{(min + ((index + 1) * width)).round(0)}",
        count: count
      }
    end
  end

  def top_earners(salaries)
    salaries.group_by { |salary| salary[:currency] }.transform_values do |group|
      group.sort_by { |salary| -salary[:annualized] }.first(10).map do |salary|
        {
          name: salary[:name],
          department: salary[:department],
          country: salary[:country],
          currency: salary[:currency],
          annualized_amount: salary[:annualized]
        }
      end
    end
  end
end
