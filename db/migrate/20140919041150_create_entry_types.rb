class CreateEntryTypes < ActiveRecord::Migration[5.1]
    def change
        create_table :entry_types do |t|
            t.string :name
            t.string :check_shortname
            t.text :description
            t.text :remedy_guidance
            t.integer :cwe

            t.timestamps
        end
        add_index :entry_types, :name, unique: true
        add_index :entry_types, :check_shortname, unique: true
    end
end
