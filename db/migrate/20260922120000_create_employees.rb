class CreateEmployees < ActiveRecord::Migration[8.1]
  def change
    create_table :employees do |t|
      t.string :name, null: false
      t.string :email, null: false
      t.string :job_title, null: false
      t.string :department, null: false
      t.string :country, null: false
      t.string :currency, null: false
      t.date :hire_date, null: false
      t.string :status, null: false, default: "active"

      t.timestamps
    end

    add_index :employees, :email, unique: true
    add_index :employees, :department
    add_index :employees, :country
    add_index :employees, :status
  end
end
