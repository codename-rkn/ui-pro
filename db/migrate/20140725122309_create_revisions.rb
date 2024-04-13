class CreateRevisions < ActiveRecord::Migration[5.1]
  def change
    create_table :revisions do |t|
      t.belongs_to :scan, index: true
      t.belongs_to :site, index: true
      t.integer :index
      t.binary :rpc_options
      t.text :snapshot_path
      t.text :error_messages
      t.string :seed
      t.string :status
      t.boolean :timed_out, default: false
      t.datetime :started_at
      t.datetime :stopped_at

      t.integer :entries_count, default: 0
      t.integer :sitemap_entries_count, default: 0

      t.timestamps
    end
  end
end
