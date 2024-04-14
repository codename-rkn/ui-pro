class CreateNotes < ActiveRecord::Migration[7.0]
  def change
    create_table :notes do |t|
      t.text :text
      t.belongs_to :entry

      t.timestamps
    end
  end
end
