class CreateEntryPages < ActiveRecord::Migration[5.1]
    def change
        create_table :entry_pages do |t|
            t.belongs_to :sitemap_entry
            t.timestamps
        end
    end
end
