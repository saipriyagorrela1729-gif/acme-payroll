# Aggregates "how the org pays people" from the current salary of every employee.
# All comparisons use the annualized amount, always grouped by currency (no FX).
# Every metric is computed in SQL (window functions + set aggregation), so no
# employee rows are loaded into Ruby memory.
class PayrollStats
  BUCKET_COUNT = 10

  def call
    current = SalaryRecord.current.joins(:employee)

    {
      headcount: headcount,
      payroll: payroll(current),
      by_department: grouped(current, "employees.department"),
      by_country: grouped(current, "employees.country"),
      distribution: distribution,
      top_earners: top_earners
    }
  end

  private

  def annualized_sql
    Arel.sql(SalaryRecord::ANNUALIZED_SQL)
  end

  def headcount
    {
      total: Employee.count,
      active: Employee.active.count,
      terminated: Employee.where(status: "terminated").count
    }
  end

  def payroll(current)
    current.group("salary_records.currency")
      .pluck("salary_records.currency", Arel.sql("SUM(#{annualized_sql}) AS total"))
      .to_h do |currency, total|
        annualized = total.to_f
        [ currency, { "annualized" => annualized, "monthly" => (annualized / 12).round(2) } ]
      end
  end

  def grouped(current, column)
    current.group(column, "salary_records.currency")
      .pluck(
        column,
        "salary_records.currency",
        Arel.sql("COUNT(*) AS count"),
        Arel.sql("ROUND(AVG(#{annualized_sql})) AS average"),
        Arel.sql("ROUND(PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY #{annualized_sql})) AS median")
      )
      .map do |name, currency, count, average, median|
        {
          name: name,
          currency: currency,
          employees: count,
          average: average.to_f,
          median: median.to_f
        }
      end
  end

  def distribution
    rows = SalaryRecord.connection.select_all(<<~SQL.squish).to_a
      SELECT currency, band, COUNT(*) AS count, MIN(min_amount) AS min_amount, MAX(max_amount) AS max_amount
      FROM (
        SELECT
          cs.currency,
          WIDTH_BUCKET(cs.annualized, MIN(cs.annualized) OVER w, MAX(cs.annualized) OVER w + 0.01, #{BUCKET_COUNT}) AS band,
          MIN(cs.annualized) OVER w AS min_amount,
          MAX(cs.annualized) OVER w AS max_amount
        FROM (
          SELECT salary_records.currency, #{SalaryRecord::ANNUALIZED_SQL} AS annualized
          FROM salary_records
          WHERE salary_records.id IN (
            SELECT DISTINCT ON (employee_id) id
            FROM salary_records
            ORDER BY employee_id, effective_date DESC, id DESC
          )
        ) cs
        WINDOW w AS (PARTITION BY cs.currency)
      ) t
      GROUP BY currency, band, min_amount, max_amount
      ORDER BY currency, band
    SQL

    rows.group_by { |row| row["currency"] }.transform_values do |group|
      min = group.first["min_amount"].to_f
      max = group.first["max_amount"].to_f
      width = (max - min) / BUCKET_COUNT.to_f
      counts = Array.new(BUCKET_COUNT, 0)
      group.each { |row| counts[row["band"].to_i - 1] = row["count"] }

      counts.each_with_index.map do |count, index|
        {
          band: index + 1,
          label: "#{(min + (index * width)).round(0)}–#{(min + ((index + 1) * width)).round(0)}",
          count: count
        }
      end
    end
  end

  def top_earners
    rows = SalaryRecord.connection.select_all(<<~SQL.squish).to_a
      SELECT currency, name, department, country, annualized_amount
      FROM (
        SELECT
          salary_records.currency,
          employees.name,
          employees.department,
          employees.country,
          #{SalaryRecord::ANNUALIZED_SQL} AS annualized_amount,
          ROW_NUMBER() OVER (
            PARTITION BY salary_records.currency
            ORDER BY #{SalaryRecord::ANNUALIZED_SQL} DESC
          ) AS rank
        FROM salary_records
        JOIN employees ON employees.id = salary_records.employee_id
        WHERE salary_records.id IN (
          SELECT DISTINCT ON (employee_id) id
          FROM salary_records
          ORDER BY employee_id, effective_date DESC, id DESC
        )
      ) ranked
      WHERE rank <= 10
    SQL

    rows.group_by { |row| row["currency"] }.transform_values do |group|
      group.map do |row|
        {
          name: row["name"],
          department: row["department"],
          country: row["country"],
          currency: row["currency"],
          annualized_amount: row["annualized_amount"].to_f
        }
      end
    end
  end
end
