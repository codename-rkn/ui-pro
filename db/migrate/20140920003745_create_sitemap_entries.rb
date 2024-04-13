class CreateSitemapEntries < ActiveRecord::Migration[5.1]
    def change
        create_table :sitemap_entries do |t|
            t.boolean :coverage
            t.text :url
            t.integer :code
            t.integer :entries_count, default: 0
            t.integer :entry_pages_count, default: 0
            t.integer :input_vectors_count, default: 0

            t.bigint :digest, index: true

            # We could have done this via a through :revisions association in
            # the model but we need it here for deduplication and easier analytics.
            t.belongs_to :site, index: true
            t.belongs_to :scan, index: true
            t.belongs_to :revision, index: true

            t.timestamps
        end

        add_index :sitemap_entries, [:digest, :revision_id], unique: true
    end
end
