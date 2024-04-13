class CreateEntryTypesEntryTypeTags < ActiveRecord::Migration[5.1]
    def change
        create_table :entry_types_entry_type_tags do |t|
            t.integer :entry_type_id
            t.integer :entry_type_tag_id
        end
    end
end
