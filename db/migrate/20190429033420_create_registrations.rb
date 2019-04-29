class CreateRegistrations < ActiveRecord::Migration[5.2]
  def change
    create_table :registrations do |t|
      t.text :name
      t.text :key_handle
      t.text :public_key
      t.integer :counter

      t.timestamps
    end
  end
end
