# Seeds 10,000 employees with salary history.
# Usage: bin/rails db:seed   (or: bin/rails seed:benchmark)
result = Seed::DatabasePopulator.new.call
puts "Seeded #{result[:employee_count]} employees and #{result[:salary_record_count]} salary records " \
     "(employees: #{result[:timings][:employees].round(2)}s, salary_records: #{result[:timings][:salary_records].round(2)}s)"
