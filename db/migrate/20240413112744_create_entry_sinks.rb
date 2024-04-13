class CreateEntrySinks < ActiveRecord::Migration[7.0]
  def change
    create_table :entry_sinks do |t|
      t.string :name
      t.timestamps
    end
    add_index :entry_sinks, :name, unique: true
  end
end
