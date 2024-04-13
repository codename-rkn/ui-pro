class CreateScans < ActiveRecord::Migration[5.1]
  def change
    create_table :scans do |t|
      t.string :name
      t.text :description
      t.text :path
      t.string :status
      t.boolean :timed_out, default: false
      t.integer :revisions_count, default: 0
      t.integer :entries_count, default: 0
      t.integer :sitemap_entries_count, default: 0

      t.belongs_to :site, index: true
      t.belongs_to :device
      t.belongs_to :site_role

      t.timestamps
    end
  end
end
