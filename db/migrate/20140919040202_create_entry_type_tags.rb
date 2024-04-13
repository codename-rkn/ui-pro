class CreateEntryTypeTags < ActiveRecord::Migration[5.1]
    def change
        create_table :entry_type_tags do |t|
            t.string :name
            t.text :description

            t.timestamps
        end
        add_index :entry_type_tags, :name, unique: true
    end
end
