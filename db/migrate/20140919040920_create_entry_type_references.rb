class CreateEntryTypeReferences < ActiveRecord::Migration[5.1]
    def change
        create_table :entry_type_references do |t|
            t.string :title
            t.text :url
            t.belongs_to :entry_type, index: true

            t.timestamps
        end
    end
end
