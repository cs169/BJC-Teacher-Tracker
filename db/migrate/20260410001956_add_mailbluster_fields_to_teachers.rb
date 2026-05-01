class AddMailblusterFieldsToTeachers < ActiveRecord::Migration[6.1]
  def change
    add_column :teachers, :mailbluster_id, :integer
    add_column :teachers, :mailbluster_synced_at, :datetime
    add_index :teachers, :mailbluster_id, unique: true
  end
end
