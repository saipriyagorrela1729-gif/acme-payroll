namespace :seed do
  desc "Seed 10,000 employees and benchmark the runtime"
  task benchmark: :environment do
    started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    result = Seed::DatabasePopulator.new.call
    elapsed = Process.clock_gettime(Process::CLOCK_MONOTONIC) - started

    puts "Employees:          #{result[:employee_count]}"
    puts "Salary records:     #{result[:salary_record_count]}"
    puts "Insert (employees): #{result[:timings][:employees].round(2)}s"
    puts "Insert (salaries):  #{result[:timings][:salary_records].round(2)}s"
    puts "Total:              #{elapsed.round(2)}s"
    puts "Target: < 30s"
  end
end
