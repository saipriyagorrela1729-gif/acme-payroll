class CreateSalaryComponents < ActiveRecord::Migration[8.1]
  def change
    create_table :salary_components do |t|
      t.references :salary_record, null: false, foreign_key: true
      t.string :name, null: false
      t.string :kind, null: false, default: "earning"
      t.decimal :amount, precision: 12, scale: 2, null: false, default: 0
      t.integer :position, null: false, default: 0

      t.timestamps
    end

    add_index :salary_components, [ :salary_record_id, :position ]
  end
end
