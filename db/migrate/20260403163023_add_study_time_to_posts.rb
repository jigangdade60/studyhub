class AddStudyTimeToPosts < ActiveRecord::Migration[8.0]
  def change
    add_column :posts, :study_time, :integer, null: false, default: 0
  end
end