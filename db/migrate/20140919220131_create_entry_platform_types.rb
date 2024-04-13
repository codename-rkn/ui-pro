class CreateEntryPlatformTypes < ActiveRecord::Migration[5.1]
    def change
        create_table :entry_platform_types do |t|
            t.string :shortname
            t.string :name

            t.timestamps
        end
        add_index :entry_platform_types, :shortname, unique: true
        add_index :entry_platform_types, :name, unique: true
    end
end
