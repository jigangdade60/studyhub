class CreateGroups < ActiveRecord::Migration[8.0]
  def change
    create_table :groups do |t|
      t.string :name, null: false
      t.text :description, null: false
      t.text :rule
      t.string :study_theme, null: false
      t.integer :max_members, null: false, default: 10
      t.references :owner, null: false, foreign_key: { to_table: :users }

      t.timestamps
    end
  end
end