class CreateEntryTypeSeverities < ActiveRecord::Migration[5.1]
    def change
        create_table :entry_type_severities do |t|
            t.string :name
            t.text :description

            t.timestamps
        end
        add_index :entry_type_severities, :name, unique: true
    end
end
