# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.1].define(version: 2026_09_22_120100) do
  create_table "employees", force: :cascade do |t|
    t.string "country", null: false
    t.datetime "created_at", null: false
    t.string "currency", null: false
    t.string "department", null: false
    t.string "email", null: false
    t.date "hire_date", null: false
    t.string "job_title", null: false
    t.string "name", null: false
    t.string "status", default: "active", null: false
    t.datetime "updated_at", null: false
    t.index ["country"], name: "index_employees_on_country"
    t.index ["department"], name: "index_employees_on_department"
    t.index ["email"], name: "index_employees_on_email", unique: true
    t.index ["status"], name: "index_employees_on_status"
  end

  create_table "salary_records", force: :cascade do |t|
    t.decimal "amount", precision: 12, scale: 2, null: false
    t.datetime "created_at", null: false
    t.string "currency", null: false
    t.date "effective_date", null: false
    t.bigint "employee_id", null: false
    t.string "frequency", null: false
    t.datetime "updated_at", null: false
    t.index ["employee_id", "effective_date"], name: "index_salary_records_on_employee_id_and_effective_date"
    t.index ["employee_id"], name: "index_salary_records_on_employee_id"
  end

  add_foreign_key "salary_records", "employees"
end
