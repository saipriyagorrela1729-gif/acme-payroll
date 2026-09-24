# Seeds 10,000 employees with salary history + a CTC breakdown, and a default HR user.
# Usage: bin/rails db:seed   (or: bin/rails seed:benchmark)
hr = User.find_or_create_by!(email: "hr@acme.example") do |user|
  user.password = "password123"
  user.password_confirmation = "password123"
end

result = Seed::DatabasePopulator.new.call
puts "Seeded #{result[:employee_count]} employees, #{result[:salary_record_count]} salary records and " \
     "#{result[:salary_component_count]} salary components " \
     "(employees: #{result[:timings][:employees].round(2)}s, salaries: #{result[:timings][:salary_records].round(2)}s, " \
     "components: #{result[:timings][:salary_components].round(2)}s)"
puts "HR login: #{hr.email} / password123"
