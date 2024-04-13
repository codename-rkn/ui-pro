class CreateEntries < ActiveRecord::Migration[5.1]
    def change
        create_table :entries do |t|
            t.bigint :digest
            t.string :state

            t.boolean :active
            t.binary :proof
            t.binary :signature

            t.integer :referring_entry_page_id
            t.integer :reviewed_by_revision_id
            t.belongs_to :revision, index: true
            t.belongs_to :scan, index: true
            t.belongs_to :site, index: true
            t.belongs_to :entry_page, index: true
            t.belongs_to :entry_type, index: true
            t.belongs_to :entry_platform, index: true
            t.belongs_to :sitemap_entry, index: true

            t.timestamps
        end

        add_index :entries, :referring_entry_page_id
        add_index :entries, :digest
        add_index :entries, :state
        add_index :entries, :active
    end
end
