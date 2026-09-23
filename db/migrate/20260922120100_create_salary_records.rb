class CreateSalaryRecords < ActiveRecord::Migration[8.1]
  def change
    create_table :salary_records do |t|
      t.references :employee, null: false, foreign_key: true
      t.decimal :amount, precision: 12, scale: 2, null: false
      t.string :currency, null: false
      t.string :frequency, null: false
      t.date :effective_date, null: false

      t.timestamps
    end

    add_index :salary_records, [ :employee_id, :effective_date ]
  end
end
