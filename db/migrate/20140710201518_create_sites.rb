class CreateSites < ActiveRecord::Migration[5.1]
    def change
        create_table :sites do |t|
            t.integer :protocol
            t.string  :host
            t.integer :port, default: 80
            t.integer :scans_count,  default: 0
            t.integer :revisions_count,  default: 0
            t.integer :entries_count, default: 0
            t.integer :sitemap_entries_count, default: 0

            t.belongs_to :user, index: true

            t.timestamps
        end

        add_index :sites, [:protocol, :host, :port]
    end
end
