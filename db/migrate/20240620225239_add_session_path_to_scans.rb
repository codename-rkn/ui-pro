class AddSessionPathToScans < ActiveRecord::Migration[7.0]
  def change
    add_column :scans, :session_path, :text
  end
end
