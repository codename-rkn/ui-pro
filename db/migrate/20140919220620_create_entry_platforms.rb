class CreateEntryPlatforms < ActiveRecord::Migration[5.1]
    def change
        create_table :entry_platforms do |t|
            t.string :shortname
            t.string :name
            t.belongs_to :entry_platform_type, index: true
            t.belongs_to :entry, index: true

            t.timestamps
        end
        add_index :entry_platforms, :shortname, unique: true
        add_index :entry_platforms, :name, unique: true
    end
end
